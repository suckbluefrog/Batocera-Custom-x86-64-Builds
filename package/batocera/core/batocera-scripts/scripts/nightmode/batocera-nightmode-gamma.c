#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <math.h>
#include <poll.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <wayland-client.h>

#include "wlr-gamma-control-unstable-v1-protocol.h"

struct output {
    struct wl_output *wl_output;
    uint32_t name;
    struct output *next;
};

struct control {
    struct zwlr_gamma_control_v1 *gamma;
    uint32_t size;
    int failed;
    int applied;
    struct control *next;
};

struct client_state {
    struct wl_display *display;
    struct wl_registry *registry;
    struct zwlr_gamma_control_manager_v1 *manager;
    struct output *outputs;
    struct control *controls;
    double intensity;
};

static volatile sig_atomic_t exit_requested;
static volatile sig_atomic_t reset_requested;

static void handle_signal(int signum)
{
    (void)signum;
    reset_requested = 1;
    exit_requested = 1;
}

static void usage(const char *name)
{
    fprintf(stderr, "usage: %s --intensity 0-100\n", name);
}

static double clamp_double(double value, double min, double max)
{
    if (value < min)
        return min;
    if (value > max)
        return max;
    return value;
}

static uint16_t ramp_value(uint32_t index, uint32_t size, double factor)
{
    double base;
    double value;

    if (size <= 1)
        base = 0.0;
    else
        base = (double)index / (double)(size - 1);

    value = clamp_double(base * 65535.0 * factor, 0.0, 65535.0);
    return (uint16_t)lrint(value);
}

static int write_all(int fd, const void *buffer, size_t length)
{
    const uint8_t *bytes = buffer;

    while (length > 0) {
        ssize_t written = write(fd, bytes, length);
        if (written < 0) {
            if (errno == EINTR)
                continue;
            return -1;
        }

        bytes += written;
        length -= (size_t)written;
    }

    return 0;
}

static int create_gamma_fd(uint32_t size, double intensity)
{
    char path[PATH_MAX];
    const char *runtime_dir;
    int fd;
    size_t bytes;
    uint16_t *table;
    double green_factor;
    double blue_factor;

    if (size == 0)
        return -1;

    runtime_dir = getenv("XDG_RUNTIME_DIR");
    if (runtime_dir == NULL || runtime_dir[0] == '\0')
        runtime_dir = "/tmp";

    snprintf(path, sizeof(path), "%s/batocera-nightmode-gamma-XXXXXX", runtime_dir);
    fd = mkstemp(path);
    if (fd < 0)
        return -1;

    unlink(path);

    bytes = (size_t)size * 3U * sizeof(uint16_t);
    if (ftruncate(fd, (off_t)bytes) < 0) {
        close(fd);
        return -1;
    }

    table = calloc((size_t)size * 3U, sizeof(uint16_t));
    if (table == NULL) {
        close(fd);
        return -1;
    }

    intensity = clamp_double(intensity, 0.0, 100.0) / 100.0;
    green_factor = 1.0 - (0.30 * intensity);
    blue_factor = 1.0 - (0.65 * intensity);

    for (uint32_t i = 0; i < size; i++)
        table[i] = ramp_value(i, size, 1.0);
    for (uint32_t i = 0; i < size; i++)
        table[size + i] = ramp_value(i, size, green_factor);
    for (uint32_t i = 0; i < size; i++)
        table[(size * 2U) + i] = ramp_value(i, size, blue_factor);

    if (write_all(fd, table, bytes) < 0 || lseek(fd, 0, SEEK_SET) < 0) {
        free(table);
        close(fd);
        return -1;
    }

    free(table);
    return fd;
}

static void gamma_size(void *data, struct zwlr_gamma_control_v1 *gamma, uint32_t size)
{
    struct control *control = data;

    (void)gamma;
    control->size = size;
}

static void gamma_failed(void *data, struct zwlr_gamma_control_v1 *gamma)
{
    struct control *control = data;

    (void)gamma;
    control->failed = 1;
    exit_requested = 1;
}

static const struct zwlr_gamma_control_v1_listener gamma_listener = {
    .gamma_size = gamma_size,
    .failed = gamma_failed,
};

static void registry_global(void *data, struct wl_registry *registry, uint32_t name,
                            const char *interface, uint32_t version)
{
    struct client_state *state = data;

    if (strcmp(interface, wl_output_interface.name) == 0) {
        struct output *output = calloc(1, sizeof(*output));
        if (output == NULL)
            return;

        output->name = name;
        output->wl_output = wl_registry_bind(registry, name, &wl_output_interface, 1);
        output->next = state->outputs;
        state->outputs = output;
    } else if (strcmp(interface, zwlr_gamma_control_manager_v1_interface.name) == 0) {
        uint32_t bind_version = version < 1 ? version : 1;
        state->manager = wl_registry_bind(registry, name,
                                          &zwlr_gamma_control_manager_v1_interface,
                                          bind_version);
    }
}

static void registry_global_remove(void *data, struct wl_registry *registry, uint32_t name)
{
    (void)data;
    (void)registry;
    (void)name;
}

static const struct wl_registry_listener registry_listener = {
    .global = registry_global,
    .global_remove = registry_global_remove,
};

static int create_controls(struct client_state *state)
{
    struct output *output;

    for (output = state->outputs; output != NULL; output = output->next) {
        struct control *control = calloc(1, sizeof(*control));
        if (control == NULL)
            return -1;

        control->gamma = zwlr_gamma_control_manager_v1_get_gamma_control(
            state->manager, output->wl_output);
        zwlr_gamma_control_v1_add_listener(control->gamma, &gamma_listener, control);

        control->next = state->controls;
        state->controls = control;
    }

    return 0;
}

static int apply_gamma(struct client_state *state)
{
    struct control *control;
    int applied = 0;

    for (control = state->controls; control != NULL; control = control->next) {
        int fd;

        if (control->failed || control->size == 0)
            continue;

        fd = create_gamma_fd(control->size, state->intensity);
        if (fd < 0)
            continue;

        zwlr_gamma_control_v1_set_gamma(control->gamma, fd);
        control->applied = 1;
        applied++;

        wl_display_flush(state->display);
        close(fd);
    }

    return applied;
}

static void reset_gamma(struct client_state *state)
{
    state->intensity = 0.0;

    /* Some compositors retain the last gamma table after control is destroyed. */
    if (apply_gamma(state) > 0)
        wl_display_roundtrip(state->display);
}

static void destroy_state(struct client_state *state)
{
    struct control *control = state->controls;
    struct output *output = state->outputs;

    while (control != NULL) {
        struct control *next = control->next;
        if (control->gamma != NULL)
            zwlr_gamma_control_v1_destroy(control->gamma);
        free(control);
        control = next;
    }

    while (output != NULL) {
        struct output *next = output->next;
        if (output->wl_output != NULL)
            wl_output_destroy(output->wl_output);
        free(output);
        output = next;
    }

    if (state->manager != NULL)
        zwlr_gamma_control_manager_v1_destroy(state->manager);
    if (state->registry != NULL)
        wl_registry_destroy(state->registry);

    if (state->display != NULL) {
        wl_display_flush(state->display);
        wl_display_disconnect(state->display);
    }
}

static int run_event_loop(struct client_state *state)
{
    int display_fd = wl_display_get_fd(state->display);

    while (!exit_requested) {
        struct pollfd pfd = {
            .fd = display_fd,
            .events = POLLIN,
        };
        int ret;

        while (wl_display_dispatch_pending(state->display) > 0) {
        }

        if (wl_display_flush(state->display) < 0 && errno != EAGAIN)
            return -1;

        ret = poll(&pfd, 1, 1000);
        if (ret < 0) {
            if (errno == EINTR)
                continue;
            return -1;
        }
        if (ret == 0)
            continue;
        if ((pfd.revents & (POLLERR | POLLHUP | POLLNVAL)) != 0)
            return -1;
        if ((pfd.revents & POLLIN) != 0 && wl_display_dispatch(state->display) < 0)
            return -1;
    }

    return 0;
}

int main(int argc, char **argv)
{
    struct client_state state;
    char *end = NULL;
    int applied;

    memset(&state, 0, sizeof(state));

    if (argc != 3 || strcmp(argv[1], "--intensity") != 0) {
        usage(argv[0]);
        return 2;
    }

    errno = 0;
    state.intensity = strtod(argv[2], &end);
    if (errno != 0 || end == argv[2] || *end != '\0') {
        usage(argv[0]);
        return 2;
    }
    state.intensity = clamp_double(state.intensity, 0.0, 100.0);

    signal(SIGTERM, handle_signal);
    signal(SIGINT, handle_signal);

    state.display = wl_display_connect(NULL);
    if (state.display == NULL) {
        fprintf(stderr, "batocera-nightmode-gamma: unable to connect to Wayland display\n");
        return 1;
    }

    state.registry = wl_display_get_registry(state.display);
    wl_registry_add_listener(state.registry, &registry_listener, &state);

    if (wl_display_roundtrip(state.display) < 0) {
        destroy_state(&state);
        return 1;
    }

    if (state.manager == NULL || state.outputs == NULL) {
        fprintf(stderr, "batocera-nightmode-gamma: gamma-control protocol or outputs unavailable\n");
        destroy_state(&state);
        return 1;
    }

    if (create_controls(&state) < 0 || wl_display_roundtrip(state.display) < 0) {
        destroy_state(&state);
        return 1;
    }

    applied = apply_gamma(&state);
    if (applied <= 0) {
        fprintf(stderr, "batocera-nightmode-gamma: no output accepted gamma control\n");
        destroy_state(&state);
        return 1;
    }

    fprintf(stderr, "batocera-nightmode-gamma: applied intensity %.0f to %d output(s)\n",
            state.intensity, applied);
    run_event_loop(&state);

    if (reset_requested)
        reset_gamma(&state);

    destroy_state(&state);

    return 0;
}
