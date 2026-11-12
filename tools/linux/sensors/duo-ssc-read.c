// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * duo-ssc-read: stream any Qualcomm SSC sensor by data type, through libssc (0.4+), one line per event:
 *     <data type> <float> <float> ...
 * The Surface Duo's SLPI has Microsoft sensors libssc has no class for: "hinge_angle" (degrees: 0 closed, 180 flat,
 * ~360 folded back to back) and "posture". libssc's generic SSCSensor finds the sensor, reads its attributes
 * (on-change or continuous) and enables it; the raw measurement reports (msg 1025, sns_std_sensor_event: field 1 =
 * repeated float) come from the client's "report" signal and are decoded here.
 *   usage: duo-ssc-read [-n <events>] <data type> [<data type> ...]       e.g. duo-ssc-read hinge_angle posture
 * Build: cc -O2 -o duo-ssc-read duo-ssc-read.c $(pkg-config --cflags --libs libssc gio-2.0)
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <glib.h>
#include <gio/gio.h>
#include <libssc/libssc-sensor.h>

#define MSG_MEASUREMENT 1025

static GMainLoop *loop;
static long remaining = -1;  /* -1: forever */
static guint open_count, want_count;

typedef struct { SSCSensor *sensor; gchar *type; guint64 hi, lo; } Ctx;

/* protobuf varint */
static gboolean varint(const guint8 **p, const guint8 *end, guint64 *v)
{
	guint64 r = 0; int s = 0;
	while (*p < end && s < 64) { guint8 b = *(*p)++; r |= (guint64)(b & 0x7f) << s; if (!(b & 0x80)) { *v = r; return TRUE; } s += 7; }
	return FALSE;
}

/* field 1 of sns_std_sensor_event: repeated float, packed (wire 2) or not (wire 5) */
static int decode_floats(const guint8 *p, gsize len, float *out, int max)
{
	const guint8 *end = p + len; int n = 0; guint64 key, v;
	while (p < end && varint(&p, end, &key)) {
		guint f = key >> 3, w = key & 7;
		if (w == 5) { if (end - p < 4) break; if (f == 1 && n < max) memcpy(&out[n++], p, 4); p += 4; }
		else if (w == 2) { if (!varint(&p, end, &v) || (guint64)(end - p) < v) break;
			if (f == 1) for (guint64 i = 0; i + 4 <= v && n < max; i += 4) memcpy(&out[n++], p + i, 4);
			p += v; }
		else if (w == 0) { if (!varint(&p, end, &v)) break; }
		else if (w == 1) { if (end - p < 8) break; p += 8; }
		else break;
	}
	return n;
}

static void report(GObject *client, guint msg_id, guint64 hi, guint64 lo, GArray *buf, Ctx *c)
{
	(void)client;
	if (msg_id != MSG_MEASUREMENT || hi != c->hi || lo != c->lo) return;
	float v[32]; int n = decode_floats((const guint8 *)buf->data, buf->len, v, 32);
	GString *s = g_string_new(c->type);
	for (int i = 0; i < n; i++) g_string_append_printf(s, " %.3f", v[i]);
	puts(s->str); fflush(stdout); g_string_free(s, TRUE);
	if (remaining > 0 && --remaining == 0) g_main_loop_quit(loop);
}

static void opened(GObject *src, GAsyncResult *res, gpointer data)
{
	Ctx *c = data; g_autoptr(GError) e = NULL;
	if (!ssc_sensor_open_finish(SSC_SENSOR(src), res, &e)) { fprintf(stderr, "%s: open failed: %s\n", c->type, e->message); exit(2); }
	fprintf(stderr, "%s: open\n", c->type); open_count++;
}

static void created(GObject *src, GAsyncResult *res, gpointer data)
{
	Ctx *c = data; g_autoptr(GError) e = NULL; GObject *client = NULL; gchar *name = NULL, *vendor = NULL;
	(void)src;
	c->sensor = ssc_sensor_new_finish(res, &e);
	if (!c->sensor) { fprintf(stderr, "%s: no such sensor: %s\n", c->type, e ? e->message : "?"); exit(2); }
	g_object_get(c->sensor, SSC_SENSOR_UID_HIGH, &c->hi, SSC_SENSOR_UID_LOW, &c->lo, SSC_SENSOR_CLIENT, &client,
		     SSC_SENSOR_NAME, &name, SSC_SENSOR_VENDOR, &vendor, NULL);
	fprintf(stderr, "%s: \"%s\" (%s)\n", c->type, name ? name : "?", vendor ? vendor : "?");
	g_free(name); g_free(vendor);
	g_signal_connect(client, "report", G_CALLBACK(report), c);
	ssc_sensor_open(c->sensor, NULL, opened, c);
}

int main(int argc, char **argv)
{
	int i = 1;
	if (i + 1 < argc && !strcmp(argv[i], "-n")) { remaining = atol(argv[i + 1]); i += 2; }
	if (i >= argc) { fprintf(stderr, "usage: %s [-n events] <data type> ...\n", argv[0]); return 1; }
	loop = g_main_loop_new(NULL, FALSE);
	for (; i < argc; i++) { Ctx *c = g_new0(Ctx, 1); c->type = argv[i]; want_count++; ssc_sensor_new(c->type, NULL, created, c); }
	g_main_loop_run(loop);
	return 0;
}
