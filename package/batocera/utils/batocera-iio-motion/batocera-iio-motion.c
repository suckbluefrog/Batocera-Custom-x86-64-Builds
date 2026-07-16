/*
 * Linux IIO to DSU/CemuHook bridge for Batocera.
 *
 * DSU server protocol handling is derived from the Apache-2.0 gCemuhook
 * implementation, Copyright 2022 v1993, and the Batocera Qualcomm motion
 * bridge. The IIO bridge and Batocera integration are GPL-3.0-or-later.
 *
 * SPDX-License-Identifier: Apache-2.0 AND GPL-3.0-or-later
 */

#define _GNU_SOURCE

#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <glob.h>
#include <limits.h>
#include <math.h>
#include <poll.h>
#include <signal.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>
#include <zlib.h>

#define DSU_PROTOCOL_VERSION 1001
#define DSU_HEADER_BASE 16
#define DSU_HEADER_FULL 20
#define DSU_MSG_VERSION 0x100000U
#define DSU_MSG_PORTS 0x100001U
#define DSU_MSG_DATA 0x100002U
#define DSU_SLOT_CONNECTED 2
#define DSU_DEVICE_GYRO_FULL 2
#define DSU_CONNECTION_OTHER 0
#define DSU_BATTERY_FULL 5
#define DSU_REG_ALL 0
#define DSU_REG_SLOT 1
#define DSU_REG_MAC 2
#define DSU_DEFAULT_PORT 26760
#define DSU_CLIENT_TIMEOUT_US (5ULL * 1000000ULL)
#define DSU_MAX_CLIENTS 32
#define EARTH_GRAVITY 9.80665
#define RAD_TO_DEG (180.0 / M_PI)
#define DEFAULT_RATE_HZ 100
#define DEFAULT_CALIBRATION_SAMPLES 100
#define GYRO_CALIBRATION_MAX_DPS 8.0
#define GYRO_CALIBRATION_MAX_STDDEV_DPS 0.5
#define GYRO_DEFAULT_DEADZONE_DPS 0.35
#define READY_FILE "/var/run/batocera-motion.ready"

/* Locally administered stable identifier: 02:42:41:54:49:4f ("BATIO"). */
#define DEVICE_MAC 0x02424154494fULL

typedef struct {
	bool active;
	uint32_t id;
	uint32_t packet_counter;
	uint64_t last_request;
	struct sockaddr_storage address;
	socklen_t address_length;
} DsuClient;

typedef struct {
	char base[PATH_MAX];
	char name[128];
	int accel_fd[3];
	int gyro_fd[3];
	double accel_scale;
	double gyro_scale;
	double matrix[3][3];
	bool raw_axes;
} IioSensor;

typedef struct {
	int socket_fd;
	uint32_t server_id;
	DsuClient clients[DSU_MAX_CLIENTS];
	IioSensor sensor;
	float accel[3];
	float gyro[3];
	double gyro_bias[3];
	double calibration_mean[3];
	double calibration_m2[3];
	unsigned int calibration_count;
	unsigned int calibration_target;
	bool gyro_calibrated;
	double gyro_deadzone;
	const char *calibration_file;
	bool verbose;
} MotionServer;

static volatile sig_atomic_t keep_running = 1;

static uint16_t
read_le16(const uint8_t *data)
{
	uint16_t value;
	memcpy(&value, data, sizeof(value));
#if __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
	value = __builtin_bswap16(value);
#endif
	return value;
}

static uint32_t
read_le32(const uint8_t *data)
{
	uint32_t value;
	memcpy(&value, data, sizeof(value));
#if __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
	value = __builtin_bswap32(value);
#endif
	return value;
}

static void
write_le16(uint8_t *data, uint16_t value)
{
#if __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
	value = __builtin_bswap16(value);
#endif
	memcpy(data, &value, sizeof(value));
}

static void
write_le32(uint8_t *data, uint32_t value)
{
#if __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
	value = __builtin_bswap32(value);
#endif
	memcpy(data, &value, sizeof(value));
}

static void
write_le64(uint8_t *data, uint64_t value)
{
#if __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
	value = __builtin_bswap64(value);
#endif
	memcpy(data, &value, sizeof(value));
}

static void
write_float_le(uint8_t *data, float value)
{
	uint32_t bits;
	memcpy(&bits, &value, sizeof(bits));
	write_le32(data, bits);
}

static uint64_t
monotonic_us(void)
{
	struct timespec now;
	clock_gettime(CLOCK_MONOTONIC, &now);
	return (uint64_t)now.tv_sec * 1000000ULL + (uint64_t)now.tv_nsec / 1000ULL;
}

static void
finish_crc(uint8_t *packet, size_t length)
{
	uLong crc;
	write_le32(packet + 8, 0);
	crc = crc32(0L, packet, (uInt)length);
	write_le32(packet + 8, (uint32_t)crc);
}

static void
fill_header(uint8_t *packet, size_t length, char peer, uint32_t peer_id,
	    uint32_t message_type)
{
	memset(packet, 0, length);
	memcpy(packet, "DSU?", 4);
	packet[3] = (uint8_t)peer;
	write_le16(packet + 4, DSU_PROTOCOL_VERSION);
	write_le16(packet + 6, (uint16_t)(length - DSU_HEADER_BASE));
	write_le32(packet + 12, peer_id);
	write_le32(packet + 16, message_type);
}

static bool
validate_header(uint8_t *packet, size_t length, char peer, uint32_t *peer_id,
		uint32_t *message_type)
{
	uint32_t expected_crc;
	uint32_t actual_crc;

	if (length < DSU_HEADER_FULL || memcmp(packet, "DSU", 3) != 0 ||
	    packet[3] != (uint8_t)peer ||
	    read_le16(packet + 4) != DSU_PROTOCOL_VERSION ||
	    read_le16(packet + 6) != length - DSU_HEADER_BASE)
		return false;

	expected_crc = read_le32(packet + 8);
	write_le32(packet + 8, 0);
	actual_crc = (uint32_t)crc32(0L, packet, (uInt)length);
	write_le32(packet + 8, expected_crc);
	if (expected_crc != actual_crc)
		return false;

	if (peer_id != NULL)
		*peer_id = read_le32(packet + 12);
	if (message_type != NULL)
		*message_type = read_le32(packet + 16);
	return true;
}

static void
write_mac(uint8_t *data)
{
	data[0] = (uint8_t)(DEVICE_MAC >> 40);
	data[1] = (uint8_t)(DEVICE_MAC >> 32);
	data[2] = (uint8_t)(DEVICE_MAC >> 24);
	data[3] = (uint8_t)(DEVICE_MAC >> 16);
	data[4] = (uint8_t)(DEVICE_MAC >> 8);
	data[5] = (uint8_t)DEVICE_MAC;
}

static uint64_t
read_mac(const uint8_t *data)
{
	uint64_t value = 0;
	unsigned int i;

	for (i = 0; i < 6; i++)
		value = (value << 8) | data[i];
	return value;
}

static void
fill_controller_header(uint8_t *data, uint8_t slot)
{
	data[0] = slot;
	if (slot != 0)
		return;

	data[1] = DSU_SLOT_CONNECTED;
	data[2] = DSU_DEVICE_GYRO_FULL;
	data[3] = DSU_CONNECTION_OTHER;
	write_mac(data + 4);
	data[10] = DSU_BATTERY_FULL;
}

static int
read_text(const char *path, char *buffer, size_t size)
{
	FILE *file = fopen(path, "r");

	if (file == NULL)
		return -1;
	if (fgets(buffer, (int)size, file) == NULL) {
		fclose(file);
		return -1;
	}
	fclose(file);
	buffer[strcspn(buffer, "\r\n")] = '\0';
	return 0;
}

static int
read_double_file(const char *path, double *value)
{
	char buffer[128];
	char *end = NULL;

	if (read_text(path, buffer, sizeof(buffer)) < 0)
		return -1;
	errno = 0;
	*value = strtod(buffer, &end);
	return errno == 0 && end != buffer ? 0 : -1;
}

static int
write_int_file(const char *path, int value)
{
	FILE *file = fopen(path, "w");

	if (file == NULL)
		return -1;
	if (fprintf(file, "%d\n", value) < 0) {
		fclose(file);
		return -1;
	}
	return fclose(file);
}

static bool
has_motion_channels(const char *base)
{
	static const char *channels[] = {
		"in_accel_x_raw", "in_accel_y_raw", "in_accel_z_raw",
		"in_anglvel_x_raw", "in_anglvel_y_raw", "in_anglvel_z_raw",
	};
	char path[PATH_MAX];
	unsigned int i;

	for (i = 0; i < sizeof(channels) / sizeof(channels[0]); i++) {
		snprintf(path, sizeof(path), "%s/%s", base, channels[i]);
		if (access(path, R_OK) != 0)
			return false;
	}
	return true;
}

static int
find_sensor(char *result, size_t size, bool list_only)
{
	glob_t devices = {0};
	size_t i;
	int found = -1;

	if (glob("/sys/bus/iio/devices/iio:device*", 0, NULL, &devices) != 0)
		return -1;

	for (i = 0; i < devices.gl_pathc; i++) {
		char name_path[PATH_MAX];
		char name[128] = "unknown";

		if (!has_motion_channels(devices.gl_pathv[i]))
			continue;
		snprintf(name_path, sizeof(name_path), "%s/name", devices.gl_pathv[i]);
		(void)read_text(name_path, name, sizeof(name));
		if (list_only)
			printf("%s %s\n", devices.gl_pathv[i], name);
		if (found < 0) {
			snprintf(result, size, "%s", devices.gl_pathv[i]);
			found = 0;
		}
	}

	globfree(&devices);
	return found;
}

static int
parse_matrix(char *text, double matrix[3][3])
{
	char *cursor = text;
	char *end = NULL;
	unsigned int i;

	for (i = 0; text[i] != '\0'; i++) {
		if (text[i] == ',' || text[i] == ';')
			text[i] = ' ';
	}

	for (i = 0; i < 9; i++) {
		while (*cursor == ' ' || *cursor == '\t')
			cursor++;
		errno = 0;
		matrix[i / 3][i % 3] = strtod(cursor, &end);
		if (errno != 0 || end == cursor)
			return -1;
		cursor = end;
	}
	return 0;
}

static int
open_raw_channel(const char *base, const char *type, char axis)
{
	char path[PATH_MAX];

	snprintf(path, sizeof(path), "%s/in_%s_%c_raw", base, type, axis);
	return open(path, O_RDONLY | O_CLOEXEC);
}

static int
read_raw_channel(int fd, long *value)
{
	char buffer[64];
	char *end = NULL;
	ssize_t length;

	if (lseek(fd, 0, SEEK_SET) < 0)
		return -1;
	length = read(fd, buffer, sizeof(buffer) - 1);
	if (length <= 0)
		return -1;
	buffer[length] = '\0';
	errno = 0;
	*value = strtol(buffer, &end, 10);
	return errno == 0 && end != buffer ? 0 : -1;
}

static void
close_sensor(IioSensor *sensor)
{
	unsigned int i;

	for (i = 0; i < 3; i++) {
		if (sensor->accel_fd[i] >= 0)
			close(sensor->accel_fd[i]);
		if (sensor->gyro_fd[i] >= 0)
			close(sensor->gyro_fd[i]);
		sensor->accel_fd[i] = -1;
		sensor->gyro_fd[i] = -1;
	}
}

static int
open_sensor(IioSensor *sensor, const char *base, int rate)
{
	static const char axes[] = {'x', 'y', 'z'};
	char path[PATH_MAX];
	char matrix_text[256];
	const char *matrix_override = getenv("BATOCERA_IIO_MOTION_MATRIX");
	unsigned int i;

	memset(sensor, 0, sizeof(*sensor));
	for (i = 0; i < 3; i++) {
		sensor->accel_fd[i] = -1;
		sensor->gyro_fd[i] = -1;
		sensor->matrix[i][i] = 1.0;
	}
	snprintf(sensor->base, sizeof(sensor->base), "%s", base);

	snprintf(path, sizeof(path), "%s/name", base);
	if (read_text(path, sensor->name, sizeof(sensor->name)) < 0)
		snprintf(sensor->name, sizeof(sensor->name), "unknown");

	for (i = 0; i < 3; i++) {
		sensor->accel_fd[i] = open_raw_channel(base, "accel", axes[i]);
		sensor->gyro_fd[i] = open_raw_channel(base, "anglvel", axes[i]);
		if (sensor->accel_fd[i] < 0 || sensor->gyro_fd[i] < 0) {
			close_sensor(sensor);
			return -1;
		}
	}

	snprintf(path, sizeof(path), "%s/in_accel_scale", base);
	if (read_double_file(path, &sensor->accel_scale) < 0)
		goto fail;
	snprintf(path, sizeof(path), "%s/in_anglvel_scale", base);
	if (read_double_file(path, &sensor->gyro_scale) < 0)
		goto fail;

	if (matrix_override != NULL) {
		snprintf(matrix_text, sizeof(matrix_text), "%s", matrix_override);
		if (parse_matrix(matrix_text, sensor->matrix) < 0)
			goto fail;
	} else {
		snprintf(path, sizeof(path), "%s/in_accel_mount_matrix", base);
		if (read_text(path, matrix_text, sizeof(matrix_text)) == 0)
			(void)parse_matrix(matrix_text, sensor->matrix);
	}

	snprintf(path, sizeof(path), "%s/in_accel_sampling_frequency", base);
	(void)write_int_file(path, rate);
	snprintf(path, sizeof(path), "%s/in_anglvel_sampling_frequency", base);
	(void)write_int_file(path, rate);
	return 0;

fail:
	close_sensor(sensor);
	return -1;
}

static void
apply_matrix(const double matrix[3][3], const double input[3], double output[3])
{
	unsigned int row;
	unsigned int column;

	for (row = 0; row < 3; row++) {
		output[row] = 0.0;
		for (column = 0; column < 3; column++)
			output[row] += matrix[row][column] * input[column];
	}
}

static bool
load_calibration(MotionServer *server)
{
	FILE *file;
	char line[256];
	bool found[3] = {false, false, false};

	if (server->calibration_file == NULL)
		return false;
	file = fopen(server->calibration_file, "r");
	if (file == NULL)
		return false;

	while (fgets(line, sizeof(line), file) != NULL) {
		if (sscanf(line, "bias_x=%lf", &server->gyro_bias[0]) == 1)
			found[0] = true;
		else if (sscanf(line, "bias_y=%lf", &server->gyro_bias[1]) == 1)
			found[1] = true;
		else if (sscanf(line, "bias_z=%lf", &server->gyro_bias[2]) == 1)
			found[2] = true;
	}
	fclose(file);
	server->gyro_calibrated = found[0] && found[1] && found[2];
	return server->gyro_calibrated;
}

static void
save_calibration(const MotionServer *server)
{
	char temporary[PATH_MAX];
	FILE *file;

	if (server->calibration_file == NULL)
		return;
	snprintf(temporary, sizeof(temporary), "%s.tmp", server->calibration_file);
	file = fopen(temporary, "w");
	if (file == NULL)
		return;
	fprintf(file, "[gyroscope]\n");
	fprintf(file, "bias_x=%.9f\n", server->gyro_bias[0]);
	fprintf(file, "bias_y=%.9f\n", server->gyro_bias[1]);
	fprintf(file, "bias_z=%.9f\n", server->gyro_bias[2]);
	if (fclose(file) == 0)
		(void)rename(temporary, server->calibration_file);
	else
		(void)unlink(temporary);
}

static void
reset_calibration(MotionServer *server)
{
	memset(server->calibration_mean, 0, sizeof(server->calibration_mean));
	memset(server->calibration_m2, 0, sizeof(server->calibration_m2));
	server->calibration_count = 0;
}

static bool
calibrate_gyro(MotionServer *server, const double accel[3], const double gyro[3])
{
	double accel_magnitude = 0.0;
	double maximum_rate = 0.0;
	unsigned int i;

	if (server->gyro_calibrated)
		return true;
	if (server->calibration_target == 0) {
		server->gyro_calibrated = true;
		return true;
	}

	for (i = 0; i < 3; i++) {
		accel_magnitude += accel[i] * accel[i];
		maximum_rate = fmax(maximum_rate, fabs(gyro[i]));
	}
	accel_magnitude = sqrt(accel_magnitude);
	if (accel_magnitude < 0.85 || accel_magnitude > 1.15 ||
	    maximum_rate > GYRO_CALIBRATION_MAX_DPS) {
		reset_calibration(server);
		return false;
	}

	server->calibration_count++;
	for (i = 0; i < 3; i++) {
		double delta = gyro[i] - server->calibration_mean[i];
		server->calibration_mean[i] += delta / server->calibration_count;
		server->calibration_m2[i] +=
			delta * (gyro[i] - server->calibration_mean[i]);
	}

	if (server->calibration_count < server->calibration_target)
		return false;

	for (i = 0; i < 3; i++) {
		double variance = server->calibration_m2[i] /
			(server->calibration_count - 1);
		if (sqrt(variance) > GYRO_CALIBRATION_MAX_STDDEV_DPS) {
			reset_calibration(server);
			return false;
		}
		server->gyro_bias[i] = server->calibration_mean[i];
	}
	server->gyro_calibrated = true;
	save_calibration(server);
	fprintf(stderr, "IIO motion: gyro calibrated (%.3f, %.3f, %.3f) deg/s\n",
		server->gyro_bias[0], server->gyro_bias[1], server->gyro_bias[2]);
	return true;
}

static bool
read_motion_sample(MotionServer *server)
{
	long accel_raw[3];
	long gyro_raw[3];
	double accel_sensor[3];
	double gyro_sensor[3];
	double accel[3];
	double gyro[3];
	unsigned int i;

	for (i = 0; i < 3; i++) {
		if (read_raw_channel(server->sensor.accel_fd[i], &accel_raw[i]) < 0 ||
		    read_raw_channel(server->sensor.gyro_fd[i], &gyro_raw[i]) < 0)
			return false;
		accel_sensor[i] = accel_raw[i] * server->sensor.accel_scale /
			EARTH_GRAVITY;
		gyro_sensor[i] = gyro_raw[i] * server->sensor.gyro_scale *
			RAD_TO_DEG;
	}

	if (server->sensor.raw_axes) {
		memcpy(accel, accel_sensor, sizeof(accel));
		memcpy(gyro, gyro_sensor, sizeof(gyro));
	} else {
		apply_matrix(server->sensor.matrix, accel_sensor, accel);
		apply_matrix(server->sensor.matrix, gyro_sensor, gyro);
	}

	if (!calibrate_gyro(server, accel, gyro))
		return false;

	for (i = 0; i < 3; i++) {
		double corrected = gyro[i] - server->gyro_bias[i];
		server->accel[i] = (float)accel[i];
		server->gyro[i] =
			(float)(fabs(corrected) < server->gyro_deadzone ? 0.0 : corrected);
	}
	return true;
}

static void
send_to_address(MotionServer *server, const uint8_t *packet, size_t length,
		const struct sockaddr *address, socklen_t address_length)
{
	ssize_t sent = sendto(server->socket_fd, packet, length, 0, address,
			      address_length);

	if (sent < 0 && server->verbose)
		fprintf(stderr, "IIO motion: DSU send failed: %s\n", strerror(errno));
}

static void
send_version(MotionServer *server, const struct sockaddr *address,
	     socklen_t address_length)
{
	uint8_t packet[DSU_HEADER_FULL + 2];

	fill_header(packet, sizeof(packet), 'S', server->server_id,
		    DSU_MSG_VERSION);
	write_le16(packet + DSU_HEADER_FULL, DSU_PROTOCOL_VERSION);
	finish_crc(packet, sizeof(packet));
	send_to_address(server, packet, sizeof(packet), address, address_length);
}

static void
send_slot_info(MotionServer *server, uint8_t slot,
	       const struct sockaddr *address, socklen_t address_length)
{
	uint8_t packet[DSU_HEADER_FULL + 12];

	fill_header(packet, sizeof(packet), 'S', server->server_id, DSU_MSG_PORTS);
	fill_controller_header(packet + DSU_HEADER_FULL, slot);
	finish_crc(packet, sizeof(packet));
	send_to_address(server, packet, sizeof(packet), address, address_length);
}

static DsuClient *
register_client(MotionServer *server, uint32_t client_id,
		const struct sockaddr *address, socklen_t address_length)
{
	DsuClient *free_slot = NULL;
	unsigned int i;

	for (i = 0; i < DSU_MAX_CLIENTS; i++) {
		DsuClient *client = &server->clients[i];

		if (client->active && client->id == client_id) {
			memcpy(&client->address, address, address_length);
			client->address_length = address_length;
			client->last_request = monotonic_us();
			return client;
		}
		if (!client->active && free_slot == NULL)
			free_slot = client;
	}

	if (free_slot == NULL)
		return NULL;
	memset(free_slot, 0, sizeof(*free_slot));
	free_slot->active = true;
	free_slot->id = client_id;
	free_slot->last_request = monotonic_us();
	memcpy(&free_slot->address, address, address_length);
	free_slot->address_length = address_length;
	if (server->verbose)
		fprintf(stderr, "IIO motion: registered DSU client %u\n", client_id);
	return free_slot;
}

static void
send_motion_data(MotionServer *server, uint64_t timestamp)
{
	uint8_t packet[DSU_HEADER_FULL + 80];
	unsigned int i;

	fill_header(packet, sizeof(packet), 'S', server->server_id, DSU_MSG_DATA);
	fill_controller_header(packet + DSU_HEADER_FULL, 0);
	packet[31] = 1;
	packet[40] = 127;
	packet[41] = 127;
	packet[42] = 127;
	packet[43] = 127;
	write_le64(packet + 68, timestamp);
	write_float_le(packet + 76, server->accel[0]);
	write_float_le(packet + 80, server->accel[1]);
	write_float_le(packet + 84, server->accel[2]);
	write_float_le(packet + 88, server->gyro[0]);
	write_float_le(packet + 92, server->gyro[1]);
	write_float_le(packet + 96, server->gyro[2]);

	for (i = 0; i < DSU_MAX_CLIENTS; i++) {
		DsuClient *client = &server->clients[i];

		if (!client->active)
			continue;
		write_le32(packet + 32, client->packet_counter++);
		finish_crc(packet, sizeof(packet));
		send_to_address(server, packet, sizeof(packet),
				(const struct sockaddr *)&client->address,
				client->address_length);
	}
}

static void
handle_socket(MotionServer *server)
{
	uint8_t packet[2048];

	for (;;) {
		struct sockaddr_storage sender;
		socklen_t sender_length = sizeof(sender);
		uint32_t client_id;
		uint32_t message_type;
		ssize_t length = recvfrom(server->socket_fd, packet, sizeof(packet), 0,
					  (struct sockaddr *)&sender, &sender_length);

		if (length < 0) {
			if (errno == EAGAIN || errno == EWOULDBLOCK)
				return;
			if (errno != EINTR)
				fprintf(stderr, "IIO motion: DSU receive failed: %s\n",
					strerror(errno));
			return;
		}
		if (!validate_header(packet, (size_t)length, 'C', &client_id,
				     &message_type))
			continue;

		switch (message_type) {
		case DSU_MSG_VERSION:
			send_version(server, (struct sockaddr *)&sender, sender_length);
			break;
		case DSU_MSG_PORTS:
			if (length >= DSU_HEADER_FULL + 4) {
				uint32_t amount = read_le32(packet + 20);
				uint32_t available = (uint32_t)length - 24U;
				uint32_t i;

				if (amount > 5)
					amount = 5;
				if (amount > available)
					amount = available;
				for (i = 0; i < amount; i++) {
					uint8_t slot = packet[24 + i];
					if (slot < 4)
						send_slot_info(server, slot,
							(struct sockaddr *)&sender,
							sender_length);
				}
			}
			break;
		case DSU_MSG_DATA:
			if (length >= DSU_HEADER_FULL + 8) {
				uint8_t registration = packet[20];
				uint8_t slot = packet[21];
				uint64_t mac = read_mac(packet + 22);
				bool requested = registration == DSU_REG_ALL ||
					((registration & DSU_REG_SLOT) && slot == 0) ||
					((registration & DSU_REG_MAC) &&
					 mac == DEVICE_MAC);

				if (requested)
					(void)register_client(server, client_id,
						(struct sockaddr *)&sender,
						sender_length);
			}
			break;
		default:
			break;
		}
	}
}

static void
expire_clients(MotionServer *server, uint64_t now)
{
	unsigned int i;

	for (i = 0; i < DSU_MAX_CLIENTS; i++) {
		DsuClient *client = &server->clients[i];

		if (client->active &&
		    now - client->last_request > DSU_CLIENT_TIMEOUT_US)
			memset(client, 0, sizeof(*client));
	}
}

static int
open_server_socket(uint16_t port)
{
	struct sockaddr_in address = {
		.sin_family = AF_INET,
		.sin_port = htons(port),
		.sin_addr.s_addr = htonl(INADDR_LOOPBACK),
	};
	int socket_fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
	int flags;

	if (socket_fd < 0)
		return -1;
	if (bind(socket_fd, (struct sockaddr *)&address, sizeof(address)) < 0) {
		close(socket_fd);
		return -1;
	}
	flags = fcntl(socket_fd, F_GETFL, 0);
	if (flags < 0 || fcntl(socket_fd, F_SETFL, flags | O_NONBLOCK) < 0) {
		close(socket_fd);
		return -1;
	}
	return socket_fd;
}

static uint32_t
random_server_id(void)
{
	uint32_t value = (uint32_t)(monotonic_us() ^ (uint64_t)getpid());
	int random_fd = open("/dev/urandom", O_RDONLY | O_CLOEXEC);

	if (random_fd >= 0) {
		uint32_t random_value;
		ssize_t bytes_read =
			read(random_fd, &random_value, sizeof(random_value));

		if (bytes_read == (ssize_t)sizeof(random_value))
			value = random_value;
		close(random_fd);
	}
	return value;
}

static void
handle_signal(int signal_number)
{
	(void)signal_number;
	keep_running = 0;
}

static void
usage(const char *program)
{
	fprintf(stderr,
		"Usage: %s [--device PATH] [--port PORT] [--rate HZ]\\n"
		"          [--calibration-file FILE] [--calibration-samples N]\\n"
		"          [--gyro-deadzone DPS] [--raw-axes] [--list] [--verbose]\\n",
		program);
}

int
main(int argc, char **argv)
{
	MotionServer server = {
		.socket_fd = -1,
		.gyro_deadzone = GYRO_DEFAULT_DEADZONE_DPS,
		.calibration_target = DEFAULT_CALIBRATION_SAMPLES,
	};
	char device[PATH_MAX] = "";
	char ready_contents[32];
	const char *calibration_file =
		"/userdata/system/configs/motion/iio-gyro.ini";
	const char *ready_file = getenv("BATOCERA_MOTION_READY_FILE");
	int port = DSU_DEFAULT_PORT;
	int rate = DEFAULT_RATE_HZ;
	bool list_only = false;
	bool raw_axes = false;
	uint64_t next_sample;
	uint64_t last_cleanup;
	unsigned int i;

	if (ready_file == NULL || ready_file[0] == '\0')
		ready_file = READY_FILE;

	for (i = 1; i < (unsigned int)argc; i++) {
		if (strcmp(argv[i], "--device") == 0 && i + 1 < (unsigned int)argc)
			snprintf(device, sizeof(device), "%s", argv[++i]);
		else if (strcmp(argv[i], "--port") == 0 && i + 1 < (unsigned int)argc)
			port = atoi(argv[++i]);
		else if (strcmp(argv[i], "--rate") == 0 && i + 1 < (unsigned int)argc)
			rate = atoi(argv[++i]);
		else if (strcmp(argv[i], "--calibration-file") == 0 &&
			 i + 1 < (unsigned int)argc)
			calibration_file = argv[++i];
		else if (strcmp(argv[i], "--calibration-samples") == 0 &&
			 i + 1 < (unsigned int)argc)
			server.calibration_target = (unsigned int)atoi(argv[++i]);
		else if (strcmp(argv[i], "--gyro-deadzone") == 0 &&
			 i + 1 < (unsigned int)argc)
			server.gyro_deadzone = strtod(argv[++i], NULL);
		else if (strcmp(argv[i], "--raw-axes") == 0)
			raw_axes = true;
		else if (strcmp(argv[i], "--list") == 0)
			list_only = true;
		else if (strcmp(argv[i], "--verbose") == 0)
			server.verbose = true;
		else {
			usage(argv[0]);
			return 2;
		}
	}

	if (port < 1 || port > 65535 || rate < 20 || rate > 400 ||
	    (server.calibration_target > 0 && server.calibration_target < 16) ||
	    server.calibration_target > 4096 ||
	    server.gyro_deadzone < 0.0 || server.gyro_deadzone > 10.0) {
		usage(argv[0]);
		return 2;
	}

	if (list_only)
		return find_sensor(device, sizeof(device), true) == 0 ? 0 : 1;
	if (device[0] == '\0' &&
	    find_sensor(device, sizeof(device), false) < 0) {
		fprintf(stderr, "IIO motion: no accelerometer/gyroscope device found\n");
		return 1;
	}
	if (!has_motion_channels(device)) {
		fprintf(stderr, "IIO motion: %s has no complete motion channel set\n",
			device);
		return 1;
	}

	if (open_sensor(&server.sensor, device, rate) < 0) {
		fprintf(stderr, "IIO motion: unable to open %s: %s\n", device,
			strerror(errno));
		return 1;
	}
	server.sensor.raw_axes = raw_axes;

	server.calibration_file = calibration_file;
	if (!load_calibration(&server) && server.calibration_target > 0)
		fprintf(stderr,
			"IIO motion: keep the handheld still for gyro calibration\n");
	else if (server.calibration_target == 0)
		server.gyro_calibrated = true;

	server.socket_fd = open_server_socket((uint16_t)port);
	if (server.socket_fd < 0) {
		fprintf(stderr, "IIO motion: unable to bind 127.0.0.1:%d: %s\n",
			port, strerror(errno));
		close_sensor(&server.sensor);
		return 1;
	}
	server.server_id = random_server_id();

	snprintf(ready_contents, sizeof(ready_contents), "%d\n", port);
	{
		FILE *ready = fopen(ready_file, "w");
		bool ready_failed = ready == NULL;

		if (!ready_failed) {
			if (fputs(ready_contents, ready) == EOF)
				ready_failed = true;
			if (fclose(ready) != 0)
				ready_failed = true;
		}
		if (ready_failed) {
			fprintf(stderr, "IIO motion: unable to create %s\n", ready_file);
			close(server.socket_fd);
			close_sensor(&server.sensor);
			return 1;
		}
	}

	signal(SIGINT, handle_signal);
	signal(SIGTERM, handle_signal);
	fprintf(stderr,
		"IIO motion: %s ready on 127.0.0.1:%d at %d Hz (scale %.9g/%.9g)\n",
		server.sensor.name, port, rate, server.sensor.accel_scale,
		server.sensor.gyro_scale);

	next_sample = monotonic_us();
	last_cleanup = next_sample;
	while (keep_running) {
		struct pollfd descriptor = {
			.fd = server.socket_fd,
			.events = POLLIN,
		};
		uint64_t now = monotonic_us();
		int timeout_ms = 0;
		int status;

		if (next_sample > now) {
			uint64_t wait_us = next_sample - now;
			timeout_ms = (int)((wait_us + 999ULL) / 1000ULL);
		}
		status = poll(&descriptor, 1, timeout_ms);
		if (status > 0 && (descriptor.revents & POLLIN))
			handle_socket(&server);
		else if (status < 0 && errno != EINTR)
			break;

		now = monotonic_us();
		if (now >= next_sample) {
			if (read_motion_sample(&server))
				send_motion_data(&server, now);
			next_sample = now + 1000000ULL / (unsigned int)rate;
		}
		if (now - last_cleanup >= 1000000ULL) {
			expire_clients(&server, now);
			last_cleanup = now;
		}
	}

	(void)unlink(ready_file);
	close(server.socket_fd);
	close_sensor(&server.sensor);
	return 0;
}
