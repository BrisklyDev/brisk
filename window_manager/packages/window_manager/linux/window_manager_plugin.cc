#include "include/window_manager/window_manager_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#define WINDOW_MANAGER_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), window_manager_plugin_get_type(), \
                              WindowManagerPlugin))

struct _WindowManagerPlugin {
  GObject parent_instance;
  FlPluginRegistrar* registrar;
  FlMethodChannel* channel;
  GdkGeometry window_geometry;
  GdkWindowHints window_hints;
  GtkWidget* _event_box;
  bool _is_prevent_close;
  bool _is_frameless;
  bool _is_always_on_top;
  bool _is_always_on_bottom;
  bool _is_dragging;
  bool _is_resizing;
  gchar* title_bar_style_;
  GdkEventButton _event_button;
  GdkDevice* grab_pointer;
  GtkCssProvider* css_provider;
};

G_DEFINE_TYPE(WindowManagerPlugin, window_manager_plugin, g_object_get_type())

// Gets the window being controlled.
GtkWindow* get_window(WindowManagerPlugin* self) {
  FlView* view = fl_plugin_registrar_get_view(self->registrar);
  if (view == nullptr)
    return nullptr;

  return GTK_WINDOW(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

GdkWindow* get_gdk_window(WindowManagerPlugin* self) {
  return gtk_widget_get_window(GTK_WIDGET(get_window(self)));
}

static FlMethodResponse* set_as_frameless(WindowManagerPlugin* self,
                                          FlValue* args) {
  gtk_window_set_decorated(get_window(self), false);

  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* destroy(WindowManagerPlugin* self) {
  self->_is_prevent_close = false;
  gtk_window_close(get_window(self));
  return FL_METHOD_RESPONSE(
      fl_method_success_response_new(fl_value_new_bool(true)));
}

static FlMethodResponse* close(WindowManagerPlugin* self) {
  gtk_window_close(get_window(self));
  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* is_prevent_close(WindowManagerPlugin* self) {
  g_autoptr(FlValue) result = fl_value_new_bool(self->_is_prevent_close);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* set_prevent_close(WindowManagerPlugin* self,
                                           FlValue* args) {
  self->_is_prevent_close =
      fl_value_get_bool(fl_value_lookup_string(args, "isPreventClose"));
  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* focus(WindowManagerPlugin* self) {
  gtk_window_present(get_window(self));
  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* blur(WindowManagerPlugin* self) {
  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* is_focused(WindowManagerPlugin* self) {
  bool is_focused = gtk_window_is_active(get_window(self));
  g_autoptr(FlValue) result = fl_value_new_bool(is_focused);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* show(WindowManagerPlugin* self) {
  gtk_widget_show(GTK_WIDGET(get_window(self)));
  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* hide(WindowManagerPlugin* self) {
  gint x, y, width, height;
  // store the bound of window before hide
  gtk_window_get_position(get_window(self), &x, &y);
  gtk_window_get_size(get_window(self), &width, &height);
  gtk_widget_hide(GTK_WIDGET(get_window(self)));
  // restore the bound of window after hide
  gtk_window_move(get_window(self), x, y);
  gtk_window_resize(get_window(self), width, height);
  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* is_visible(WindowManagerPlugin* self) {
  bool is_visible = gtk_widget_is_visible(GTK_WIDGET(get_window(self)));
  g_autoptr(FlValue) result = fl_value_new_bool(is_visible);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* is_maximized(WindowManagerPlugin* self) {
  bool is_maximized = gtk_window_is_maximized(get_window(self));
  g_autoptr(FlValue) result = fl_value_new_bool(is_maximized);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* maximize(WindowManagerPlugin* self) {
  gtk_window_maximize(get_window(self));
  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* unmaximize(WindowManagerPlugin* self) {
  gtk_window_unmaximize(get_window(self));
  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* is_minimized(WindowManagerPlugin* self) {
  GdkWindowState state = gdk_window_get_state(get_gdk_window(self));
  g_autoptr(FlValue) result =
      fl_value_new_bool(state & GDK_WINDOW_STATE_ICONIFIED);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* minimize(WindowManagerPlugin* self) {
  gtk_window_iconify(get_window(self));
  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* is_dockable(WindowManagerPlugin* self) {
  bool is_docked = false;
  g_autoptr(FlValue) result = fl_value_new_bool(is_docked);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* is_docked(WindowManagerPlugin* self) {
  g_autoptr(FlValue) result = fl_value_new_null();
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* dock(WindowManagerPlugin* self) {
  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* undock(WindowManagerPlugin* self) {
  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* restore(WindowManagerPlugin* self) {
  gtk_window_deiconify(get_window(self));
  gtk_window_present(get_window(self));
  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* is_full_screen(WindowManagerPlugin* self) {
  GdkWindowState state = gdk_window_get_state(get_gdk_window(self));
  g_autoptr(FlValue) result =
      fl_value_new_bool(state & GDK_WINDOW_STATE_FULLSCREEN);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* set_full_screen(WindowManagerPlugin* self,
                                         FlValue* args) {
  bool is_full_screen =
      fl_value_get_bool(fl_value_lookup_string(args, "isFullScreen"));

  if (is_full_screen)
    gtk_window_fullscreen(get_window(self));
  else
    gtk_window_unfullscreen(get_window(self));

  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* set_aspect_ratio(WindowManagerPlugin* self,
                                          FlValue* args) {
  const float aspect_ratio =
      fl_value_get_float(fl_value_lookup_string(args, "aspectRatio"));

  self->window_geometry.min_aspect = aspect_ratio;
  self->window_geometry.max_aspect = aspect_ratio;

  if (aspect_ratio >= 0) {
    self->window_hints =
        static_cast<GdkWindowHints>(self->window_hints | GDK_HINT_ASPECT);
  } else {
    self->window_hints =
        static_cast<GdkWindowHints>(self->window_hints & ~GDK_HINT_ASPECT);
  }

  gdk_window_set_geometry_hints(get_gdk_window(self), &self->window_geometry,
                                self->window_hints);
  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* set_background_color(WindowManagerPlugin* self,
                                              FlValue* args) {
  GdkRGBA rgba;
  rgba.red = ((double)fl_value_get_int(
                  fl_value_lookup_string(args, "backgroundColorR")) /
              255.0);
  rgba.green = ((double)fl_value_get_int(
                    fl_value_lookup_string(args, "backgroundColorG")) /
                255.0);
  rgba.blue = ((double)fl_value_get_int(
                   fl_value_lookup_string(args, "backgroundColorB")) /
               255.0);
  rgba.alpha = ((double)fl_value_get_int(
                    fl_value_lookup_string(args, "backgroundColorA")) /
                255.0);

  g_autofree gchar* color = gdk_rgba_to_string(&rgba);
  g_autofree gchar* css =
      g_strdup_printf("window { background-color: %s; }", color);

  if (self->css_provider == nullptr) {
    self->css_provider = gtk_css_provider_new();
    gtk_style_context_add_provider(
        gtk_widget_get_style_context(GTK_WIDGET(get_window(self))),
        GTK_STYLE_PROVIDER(self->css_provider),
        GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
  }

  g_autoptr(GError) error = nullptr;
  gtk_css_provider_load_from_data(self->css_provider, css, -1, &error);

  if (error != nullptr) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "setBackgroundColor", error->message, nullptr));
  }

  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* get_bounds(WindowManagerPlugin* self) {
  gint x, y, width, height;
  gtk_window_get_position(get_window(self), &x, &y);
  gtk_window_get_size(get_window(self), &width, &height);

  g_autoptr(FlValue) result_data = fl_value_new_map();
  fl_value_set_string_take(result_data, "x", fl_value_new_float(x));
  fl_value_set_string_take(result_data, "y", fl_value_new_float(y));
  fl_value_set_string_take(result_data, "width", fl_value_new_float(width));
  fl_value_set_string_take(result_data, "height", fl_value_new_float(height));

  return FL_METHOD_RESPONSE(fl_method_success_response_new(result_data));
}

static FlMethodResponse* set_bounds(WindowManagerPlugin* self, FlValue* args) {
  FlValue* x = fl_value_lookup_string(args, "x");
  FlValue* y = fl_value_lookup_string(args, "y");
  if (x != nullptr && y != nullptr) {
    gtk_window_move(get_window(self), static_cast<gint>(fl_value_get_float(x)),
                    static_cast<gint>(fl_value_get_float(y)));
  }

  FlValue* width = fl_value_lookup_string(args, "width");
  FlValue* height = fl_value_lookup_string(args, "height");
  if (width != nullptr && height != nullptr) {
    gtk_window_resize(get_window(self),
                      static_cast<gint>(fl_value_get_float(width)),
                      static_cast<gint>(fl_value_get_float(height)));
  }

  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* set_minimum_size(WindowManagerPlugin* self,
                                          FlValue* args) {
  const float width = fl_value_get_float(fl_value_lookup_string(args, "width"));
  const float height =
      fl_value_get_float(fl_value_lookup_string(args, "height"));

  if (width >= 0 && height >= 0) {
    self->window_geometry.min_width = static_cast<gint>(width);
    self->window_geometry.min_height = static_cast<gint>(height);
    self->window_hints =
        static_cast<GdkWindowHints>(self->window_hints | GDK_HINT_MIN_SIZE);
  } else {
    self->window_hints =
        static_cast<GdkWindowHints>(self->window_hints & ~GDK_HINT_MIN_SIZE);
  }

  gdk_window_set_geometry_hints(get_gdk_window(self), &self->window_geometry,
                                self->window_hints);

  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* set_maximum_size(WindowManagerPlugin* self,
                                          FlValue* args) {
  const float width = fl_value_get_float(fl_value_lookup_string(args, "width"));
  const float height =
      fl_value_get_float(fl_value_lookup_string(args, "height"));

  self->window_geometry.max_width = static_cast<gint>(width);
  self->window_geometry.max_height = static_cast<gint>(height);

  if (width >= 0 && height >= 0) {
    self->window_hints =
        static_cast<GdkWindowHints>(self->window_hints | GDK_HINT_MAX_SIZE);
  } else {
    self->window_hints =
        static_cast<GdkWindowHints>(self->window_hints & ~GDK_HINT_MAX_SIZE);
  }

  if (self->window_geometry.max_width < 0)
    self->window_geometry.max_width = G_MAXINT;
  if (self->window_geometry.max_height < 0)
    self->window_geometry.max_height = G_MAXINT;

  gdk_window_set_geometry_hints(get_gdk_window(self), &self->window_geometry,
                                self->window_hints);

  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* is_resizable(WindowManagerPlugin* self) {
  bool is_resizable = gtk_window_get_resizable(get_window(self));
  g_autoptr(FlValue) result = fl_value_new_bool(is_resizable);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* set_resizable(WindowManagerPlugin* self,
                                       FlValue* args) {
  bool is_resizable =
      fl_value_get_bool(fl_value_lookup_string(args, "isResizable"));
  gtk_window_set_resizable(get_window(self), is_resizable);
  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* is_minimizable(WindowManagerPlugin* self) {
  GdkWindowState state = gdk_window_get_state(get_gdk_window(self));
  GdkWindowTypeHint type_hint = gtk_window_get_type_hint(get_window(self));
  g_autoptr(FlValue) result =
      fl_value_new_bool(!(state & GDK_WINDOW_STATE_ICONIFIED) &&
                        type_hint == GDK_WINDOW_TYPE_HINT_NORMAL);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* set_minimizable(WindowManagerPlugin* self,
                                         FlValue* args) {
  gboolean minimizable =
      fl_value_get_bool(fl_value_lookup_string(args, "isMinimizable"));
  GdkWindowTypeHint type_hint =
      minimizable ? GDK_WINDOW_TYPE_HINT_NORMAL : GDK_WINDOW_TYPE_HINT_DIALOG;
  gtk_window_set_type_hint(get_window(self), type_hint);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

static FlMethodResponse* is_maximizable(WindowManagerPlugin* self) {
  gboolean resizable = gtk_window_get_resizable(get_window(self));
  GdkWindowState state = gdk_window_get_state(get_gdk_window(self));
  GdkWindowTypeHint type_hint = gtk_window_get_type_hint(get_window(self));
  g_autoptr(FlValue) result =
      fl_value_new_bool(resizable && !(state & GDK_WINDOW_STATE_MAXIMIZED) &&
                        type_hint == GDK_WINDOW_TYPE_HINT_NORMAL);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* set_maximizable(WindowManagerPlugin* self,
                                         FlValue* args) {
  gboolean maximizable =
      fl_value_get_bool(fl_value_lookup_string(args, "isMaximizable"));
  GdkWindowTypeHint type_hint =
      maximizable ? GDK_WINDOW_TYPE_HINT_NORMAL : GDK_WINDOW_TYPE_HINT_DIALOG;
  gtk_window_set_type_hint(get_window(self), type_hint);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

static FlMethodResponse* is_closable(WindowManagerPlugin* self) {
  bool is_closable = gtk_window_get_deletable(get_window(self));
  g_autoptr(FlValue) result = fl_value_new_bool(is_closable);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* set_closable(WindowManagerPlugin* self,
                                      FlValue* args) {
  bool is_closable =
      fl_value_get_bool(fl_value_lookup_string(args, "isClosable"));
  gtk_window_set_deletable(get_window(self), is_closable);
  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* is_always_on_top(WindowManagerPlugin* self) {
  g_autoptr(FlValue) result = fl_value_new_bool(self->_is_always_on_top);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* set_always_on_top(WindowManagerPlugin* self,
                                           FlValue* args) {
  bool isAlwaysOnTop =
      fl_value_get_bool(fl_value_lookup_string(args, "isAlwaysOnTop"));

  gtk_window_set_keep_above(get_window(self), isAlwaysOnTop);
  self->_is_always_on_top = isAlwaysOnTop;

  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* is_always_on_bottom(WindowManagerPlugin* self) {
  g_autoptr(FlValue) result = fl_value_new_bool(self->_is_always_on_bottom);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* set_always_on_bottom(WindowManagerPlugin* self,
                                              FlValue* args) {
  bool isAlwaysOnBottom =
      fl_value_get_bool(fl_value_lookup_string(args, "isAlwaysOnBottom"));

  gtk_window_set_keep_below(get_window(self), isAlwaysOnBottom);
  self->_is_always_on_bottom = isAlwaysOnBottom;

  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* get_title(WindowManagerPlugin* self) {
  const gchar* title = gtk_window_get_title(get_window(self));
  g_autoptr(FlValue) result =
      fl_value_new_string(title != nullptr ? title : "");
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* set_title(WindowManagerPlugin* self, FlValue* args) {
  const gchar* title =
      fl_value_get_string(fl_value_lookup_string(args, "title"));

  gtk_window_set_title(get_window(self), title);

  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

// Returns true if the widget is GtkHeaderBar or HdyHeaderBar from libhandy.
static gboolean is_header_bar(GtkWidget* widget) {
  return widget != nullptr &&
         (GTK_IS_HEADER_BAR(widget) ||
          g_str_has_suffix(G_OBJECT_TYPE_NAME(widget), "HeaderBar"));
}

// Recursively searches for a Gtk/HdyHeaderBar in the widget tree.
static GtkWidget* find_header_bar(GtkWidget* widget) {
  if (is_header_bar(widget)) {
    return widget;
  }

  if (GTK_IS_CONTAINER(widget)) {
    g_autoptr(GList) children =
        gtk_container_get_children(GTK_CONTAINER(widget));
    for (GList* l = children; l != nullptr; l = l->next) {
      GtkWidget* header_bar = find_header_bar(GTK_WIDGET(l->data));
      if (header_bar != nullptr) {
        return header_bar;
      }
    }
  }

  return nullptr;
}

// Returns the window's header bar which is typically a GtkHeaderBar used as
// GtkWindow::titlebar, or a HdyHeaderBar as HdyWindow granchild.
static GtkWidget* get_header_bar(GtkWindow* window) {
  GtkWidget* titlebar = gtk_window_get_titlebar(window);
  if (is_header_bar(titlebar)) {
    return titlebar;
  }
  return find_header_bar(GTK_WIDGET(window));
}

static FlMethodResponse* set_title_bar_style(WindowManagerPlugin* self,
                                             FlValue* args) {
  const gchar* title_bar_style =
      fl_value_get_string(fl_value_lookup_string(args, "titleBarStyle"));

  gboolean normal = g_strcmp0(title_bar_style, "hidden") != 0;

  GtkWidget* header_bar = get_header_bar(get_window(self));
  if (header_bar != nullptr) {
    gtk_widget_set_visible(header_bar, normal);
  } else {
    const gchar* title = gtk_window_get_title(get_window(self));
    if (title != nullptr) {
      gtk_window_set_decorated(get_window(self), normal);
    }
  }

  if (normal) {
    // Undo set_as_frameless, so that when the title bar is shown
    // again the window frame is also restored.
    gtk_window_set_decorated(get_window(self), true);
  }

  g_free(self->title_bar_style_);
  self->title_bar_style_ = g_strdup(title_bar_style);

  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* get_title_bar_height(WindowManagerPlugin* self,
                                              FlValue* args) {
  GtkWidget* widget = gtk_window_get_titlebar(get_window(self));

  int title_bar_height = 0;

  if (g_strcmp0(self->title_bar_style_, "hidden") != 0) {
    title_bar_height = gtk_widget_get_allocated_height(widget);
  }

  g_autoptr(FlValue) result = fl_value_new_int(title_bar_height);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* is_skip_taskbar(WindowManagerPlugin* self) {
  const gboolean skipping = gtk_window_get_skip_taskbar_hint(get_window(self));
  g_autoptr(FlValue) result = fl_value_new_bool(skipping);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* set_skip_taskbar(WindowManagerPlugin* self,
                                          FlValue* args) {
  bool isSkipTaskbar =
      fl_value_get_bool(fl_value_lookup_string(args, "isSkipTaskbar"));
  gtk_window_set_skip_taskbar_hint(get_window(self), isSkipTaskbar);
  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* set_icon(WindowManagerPlugin* self, FlValue* args) {
  const gchar* file_name =
      fl_value_get_string(fl_value_lookup_string(args, "iconPath"));
  const gboolean gtk_result =
      gtk_window_set_icon_from_file(get_window(self), file_name, NULL);
  g_autoptr(FlValue) result = fl_value_new_bool(gtk_result);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* get_opacity(WindowManagerPlugin* self) {
  gdouble opacity = gtk_widget_get_opacity(GTK_WIDGET(get_window(self)));
  g_autoptr(FlValue) result = fl_value_new_float(opacity);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* set_opacity(WindowManagerPlugin* self, FlValue* args) {
  gdouble opacity = fl_value_get_float(fl_value_lookup_string(args, "opacity"));
  gtk_widget_set_opacity(GTK_WIDGET(get_window(self)), opacity);
  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* pop_up_window_menu(WindowManagerPlugin* self) {
  GdkWindow* window = get_gdk_window(self);
  GdkDisplay* display = gdk_display_get_default();
  GdkSeat* seat = gdk_display_get_default_seat(display);
  GdkDevice* pointer = gdk_seat_get_pointer(seat);

  int x, y;
  gdk_device_get_position(pointer, NULL, &x, &y);

  int origin_x, origin_y;
  gdk_window_get_origin(window, &origin_x, &origin_y);

  GdkEvent* event = gdk_event_new(GDK_BUTTON_PRESS);
  event->button.window = window;
  event->button.device = pointer;
  event->button.x_root = x;
  event->button.y_root = y;
  event->button.x = x - origin_x;
  event->button.y = y - origin_y;
  gdk_window_show_window_menu(window, event);

  g_autoptr(FlValue) result = fl_value_new_float(1);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* start_dragging(WindowManagerPlugin* self) {
  auto window = get_window(self);
  auto screen = gtk_window_get_screen(window);
  auto display = gdk_screen_get_display(screen);
  auto seat = gdk_display_get_default_seat(display);
  auto device = gdk_seat_get_pointer(seat);

  gint root_x, root_y;
  gdk_device_get_position(device, nullptr, &root_x, &root_y);
  guint32 timestamp = (guint32)g_get_monotonic_time();

  gtk_window_begin_move_drag(window, 1, root_x, root_y, timestamp);
  self->_is_dragging = true;

  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static void gtk_container_children_callback(GtkWidget* widget,
                                            gpointer client_data) {
  GList** children;
  children = (GList**)client_data;
  *children = g_list_prepend(*children, widget);
}

static void find_event_box(WindowManagerPlugin* plugin, GtkWidget* widget) {
  GList* children = NULL;
  GtkWidget* current_child;
  gtk_container_forall(GTK_CONTAINER(widget), gtk_container_children_callback,
                       &children);
  while (children) {
    current_child = (GtkWidget*)children->data;
    if (GTK_IS_EVENT_BOX(current_child)) {
      plugin->_event_box = current_child;
    }
    children = children->next;
  }
}

static FlMethodResponse* start_resizing(WindowManagerPlugin* self,
                                        FlValue* args) {
  const gchar* resize_edge =
      fl_value_get_string(fl_value_lookup_string(args, "resizeEdge"));

  auto window = get_window(self);
  auto screen = gtk_window_get_screen(window);
  auto display = gdk_screen_get_display(screen);
  auto seat = gdk_display_get_default_seat(display);
  auto device = gdk_seat_get_pointer(seat);

  gint root_x, root_y;
  gdk_device_get_position(device, nullptr, &root_x, &root_y);
  guint32 timestamp = (guint32)g_get_monotonic_time();

  GdkWindowEdge gdk_window_edge = GDK_WINDOW_EDGE_NORTH_WEST;

  if (g_strcmp0(resize_edge, "topLeft") == 0) {
    gdk_window_edge = GDK_WINDOW_EDGE_NORTH_WEST;
  } else if (g_strcmp0(resize_edge, "top") == 0) {
    gdk_window_edge = GDK_WINDOW_EDGE_NORTH;
  } else if (g_strcmp0(resize_edge, "topRight") == 0) {
    gdk_window_edge = GDK_WINDOW_EDGE_NORTH_EAST;
  } else if (g_strcmp0(resize_edge, "left") == 0) {
    gdk_window_edge = GDK_WINDOW_EDGE_WEST;
  } else if (g_strcmp0(resize_edge, "right") == 0) {
    gdk_window_edge = GDK_WINDOW_EDGE_EAST;
  } else if (g_strcmp0(resize_edge, "bottomLeft") == 0) {
    gdk_window_edge = GDK_WINDOW_EDGE_SOUTH_WEST;
  } else if (g_strcmp0(resize_edge, "bottom") == 0) {
    gdk_window_edge = GDK_WINDOW_EDGE_SOUTH;
  } else if (g_strcmp0(resize_edge, "bottomRight") == 0) {
    gdk_window_edge = GDK_WINDOW_EDGE_SOUTH_EAST;
  }

  gtk_window_begin_resize_drag(window, gdk_window_edge,
                               self->_event_button.button, root_x, root_y,
                               timestamp);
  self->_is_resizing = true;

  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static const gchar* gdk_grab_status_code(GdkGrabStatus status) {
  switch (status) {
    case GDK_GRAB_SUCCESS:
      return "GDK_GRAB_SUCCESS";
    case GDK_GRAB_ALREADY_GRABBED:
      return "GDK_GRAB_ALREADY_GRABBED";
    case GDK_GRAB_INVALID_TIME:
      return "GDK_GRAB_INVALID_TIME";
    case GDK_GRAB_NOT_VIEWABLE:
      return "GDK_GRAB_NOT_VIEWABLE";
    case GDK_GRAB_FROZEN:
      return "GDK_GRAB_FROZEN";
    case GDK_GRAB_FAILED:
      return "GDK_GRAB_FAILED";
    default:
      return "GDK_GRAB_???";
  }
}

static const gchar* gdk_grab_status_message(GdkGrabStatus status) {
  switch (status) {
    case GDK_GRAB_SUCCESS:
      return "The resource was successfully grabbed.";
    case GDK_GRAB_ALREADY_GRABBED:
      return "The resource is actively grabbed by another client.";
    case GDK_GRAB_INVALID_TIME:
      return "The resource was grabbed more recently than the specified time.";
    case GDK_GRAB_NOT_VIEWABLE:
      return "The grab window or the confine_to window are not viewable.";
    case GDK_GRAB_FROZEN:
      return "The resource is frozen by an active grab of another client.";
    case GDK_GRAB_FAILED:
      return "The grab failed for some other reason.";
    default:
      return "The grab status is unknown.";
  }
}

static GdkGrabStatus gdk_grab_keyboard(WindowManagerPlugin* self) {
  g_return_val_if_fail(self->grab_pointer == nullptr, GDK_GRAB_FAILED);

  auto window = get_window(self);
  auto screen = gtk_window_get_screen(window);
  auto display = gdk_screen_get_display(screen);
  auto seat = gdk_display_get_default_seat(display);
  auto gdk_window = get_gdk_window(self);

  GdkGrabStatus status = gdk_seat_grab(
      seat, gdk_window, GDK_SEAT_CAPABILITY_KEYBOARD, false /* owner_events */,
      nullptr /* cursor */, nullptr /* event */, nullptr /*prepare_func */,
      nullptr /* prepare_func_data */);

  self->grab_pointer = gdk_seat_get_keyboard(seat);
  if (!self->grab_pointer) {
    self->grab_pointer = gdk_seat_get_pointer(seat);
  }

  return status;
}

static FlMethodResponse* grab_keyboard(WindowManagerPlugin* self) {
  GdkGrabStatus status = gdk_grab_keyboard(self);

  if (status != GDK_GRAB_SUCCESS) {
    return FL_METHOD_RESPONSE(
        fl_method_error_response_new(gdk_grab_status_code(status),
                                     gdk_grab_status_message(status), nullptr));
  }

  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* ungrab_keyboard(WindowManagerPlugin* self) {
  if (self->grab_pointer != nullptr) {
    gdk_seat_ungrab(gdk_device_get_seat(self->grab_pointer));
    self->grab_pointer = nullptr;
  }

  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* set_brightness(WindowManagerPlugin* self,
                                        FlValue* args) {
  const gchar* brightness =
      fl_value_get_string(fl_value_lookup_string(args, "brightness"));

  gboolean dark = g_strcmp0(brightness, "dark") == 0;

  GtkSettings* settings = gtk_settings_get_default();
  g_object_set(settings, "gtk-application-prefer-dark-theme", dark, nullptr);

  if (!dark) {
    // `gtk-application-prefer-dark-theme=false` is not enough to switch to the
    // light mode if the current theme is a dark variant such as "Yaru-dark" or
    // "Adwaita-dark". try switching to the light variant without a "-dark"
    // suffix.
    g_autofree gchar* theme_name = nullptr;
    g_object_get(settings, "gtk-theme-name", &theme_name, nullptr);
    if (g_str_has_suffix(theme_name, "-dark")) {
      g_autofree gchar* light_theme_name =
          g_strndup(theme_name, strlen(theme_name) - 5);
      g_object_set(settings, "gtk-theme-name", light_theme_name, nullptr);
    }
  }

  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

// Called when a method call is received from Flutter.
static void window_manager_plugin_handle_method_call(
    WindowManagerPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  if (g_strcmp0(method, "ensureInitialized") == 0) {
    g_autoptr(FlValue) result = fl_value_new_bool(true);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if (g_strcmp0(method, "waitUntilReadyToShow") == 0) {
    g_autoptr(FlValue) result = fl_value_new_bool(true);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if (g_strcmp0(method, "setAsFrameless") == 0) {
    response = set_as_frameless(self, args);
  } else if (g_strcmp0(method, "destroy") == 0) {
    response = destroy(self);
  } else if (g_strcmp0(method, "close") == 0) {
    response = close(self);
  } else if (g_strcmp0(method, "setPreventClose") == 0) {
    response = set_prevent_close(self, args);
  } else if (g_strcmp0(method, "isPreventClose") == 0) {
    response = is_prevent_close(self);
  } else if (g_strcmp0(method, "focus") == 0) {
    response = focus(self);
  } else if (g_strcmp0(method, "blur") == 0) {
    response = blur(self);
  } else if (g_strcmp0(method, "isFocused") == 0) {
    response = is_focused(self);
  } else if (g_strcmp0(method, "show") == 0) {
    response = show(self);
  } else if (g_strcmp0(method, "hide") == 0) {
    response = hide(self);
  } else if (g_strcmp0(method, "isVisible") == 0) {
    response = is_visible(self);
  } else if (g_strcmp0(method, "isMaximized") == 0) {
    response = is_maximized(self);
  } else if (g_strcmp0(method, "maximize") == 0) {
    response = maximize(self);
  } else if (g_strcmp0(method, "unmaximize") == 0) {
    response = unmaximize(self);
  } else if (g_strcmp0(method, "isMinimized") == 0) {
    response = is_minimized(self);
  } else if (g_strcmp0(method, "minimize") == 0) {
    response = minimize(self);
  } else if (g_strcmp0(method, "restore") == 0) {
    response = restore(self);
  } else if (g_strcmp0(method, "isDockable") == 0) {
    response = is_dockable(self);
  } else if (g_strcmp0(method, "isDocked") == 0) {
    response = is_docked(self);
  } else if (g_strcmp0(method, "dock") == 0) {
    response = dock(self);
  } else if (g_strcmp0(method, "undock") == 0) {
    response = undock(self);
  } else if (g_strcmp0(method, "isFullScreen") == 0) {
    response = is_full_screen(self);
  } else if (g_strcmp0(method, "setFullScreen") == 0) {
    response = set_full_screen(self, args);
  } else if (g_strcmp0(method, "setAspectRatio") == 0) {
    response = set_aspect_ratio(self, args);
  } else if (g_strcmp0(method, "setBackgroundColor") == 0) {
    response = set_background_color(self, args);
  } else if (g_strcmp0(method, "getBounds") == 0) {
    response = get_bounds(self);
  } else if (g_strcmp0(method, "setBounds") == 0) {
    response = set_bounds(self, args);
  } else if (g_strcmp0(method, "setMinimumSize") == 0) {
    response = set_minimum_size(self, args);
  } else if (g_strcmp0(method, "setMaximumSize") == 0) {
    response = set_maximum_size(self, args);
  } else if (g_strcmp0(method, "isResizable") == 0) {
    response = is_resizable(self);
  } else if (g_strcmp0(method, "setResizable") == 0) {
    response = set_resizable(self, args);
  } else if (g_strcmp0(method, "isMinimizable") == 0) {
    response = is_minimizable(self);
  } else if (g_strcmp0(method, "setMinimizable") == 0) {
    response = set_minimizable(self, args);
  } else if (g_strcmp0(method, "isMaximizable") == 0) {
    response = is_maximizable(self);
  } else if (g_strcmp0(method, "setMaximizable") == 0) {
    response = set_maximizable(self, args);
  } else if (g_strcmp0(method, "isClosable") == 0) {
    response = is_closable(self);
  } else if (g_strcmp0(method, "setClosable") == 0) {
    response = set_closable(self, args);
  } else if (g_strcmp0(method, "isAlwaysOnTop") == 0) {
    response = is_always_on_top(self);
  } else if (g_strcmp0(method, "setAlwaysOnTop") == 0) {
    response = set_always_on_top(self, args);
  } else if (g_strcmp0(method, "isAlwaysOnBottom") == 0) {
    response = is_always_on_bottom(self);
  } else if (g_strcmp0(method, "setAlwaysOnBottom") == 0) {
    response = set_always_on_bottom(self, args);
  } else if (g_strcmp0(method, "getTitle") == 0) {
    response = get_title(self);
  } else if (g_strcmp0(method, "setTitle") == 0) {
    response = set_title(self, args);
  } else if (g_strcmp0(method, "setTitleBarStyle") == 0) {
    response = set_title_bar_style(self, args);
  } else if (g_strcmp0(method, "getTitleBarHeight") == 0) {
    response = get_title_bar_height(self, args);
  } else if (g_strcmp0(method, "isSkipTaskbar") == 0) {
    response = is_skip_taskbar(self);
  } else if (g_strcmp0(method, "setSkipTaskbar") == 0) {
    response = set_skip_taskbar(self, args);
  } else if (g_strcmp0(method, "setIcon") == 0) {
    response = set_icon(self, args);
  } else if (g_strcmp0(method, "getOpacity") == 0) {
    response = get_opacity(self);
  } else if (g_strcmp0(method, "setOpacity") == 0) {
    response = set_opacity(self, args);
  } else if (g_strcmp0(method, "popUpWindowMenu") == 0) {
    response = pop_up_window_menu(self);
  } else if (g_strcmp0(method, "startDragging") == 0) {
    response = start_dragging(self);
  } else if (g_strcmp0(method, "startResizing") == 0) {
    response = start_resizing(self, args);
  } else if (g_strcmp0(method, "grabKeyboard") == 0) {
    response = grab_keyboard(self);
  } else if (g_strcmp0(method, "ungrabKeyboard") == 0) {
    response = ungrab_keyboard(self);
  } else if (g_strcmp0(method, "setBrightness") == 0) {
    response = set_brightness(self, args);
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void window_manager_plugin_dispose(GObject* object) {
  WindowManagerPlugin* self = WINDOW_MANAGER_PLUGIN(object);
  g_clear_object(&self->css_provider);
  g_free(self->title_bar_style_);
  G_OBJECT_CLASS(window_manager_plugin_parent_class)->dispose(object);
}

static void window_manager_plugin_class_init(WindowManagerPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = window_manager_plugin_dispose;
}

static void window_manager_plugin_init(WindowManagerPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel,
                           FlMethodCall* method_call,
                           gpointer user_data) {
  WindowManagerPlugin* plugin = WINDOW_MANAGER_PLUGIN(user_data);
  window_manager_plugin_handle_method_call(plugin, method_call);
}

void _emit_event(WindowManagerPlugin* plugin, const char* event_name) {
  g_autoptr(FlValue) result_data = fl_value_new_map();
  fl_value_set_string_take(result_data, "eventName",
                           fl_value_new_string(event_name));
  fl_method_channel_invoke_method(plugin->channel, "onEvent", result_data,
                                  nullptr, nullptr, nullptr);
}

gboolean on_window_close(GtkWidget* widget, GdkEvent* event, gpointer data) {
  WindowManagerPlugin* plugin = WINDOW_MANAGER_PLUGIN(data);
  _emit_event(plugin, "close");
  return plugin->_is_prevent_close;
}

gboolean on_window_focus(GtkWidget* widget, GdkEvent* event, gpointer data) {
  WindowManagerPlugin* plugin = WINDOW_MANAGER_PLUGIN(data);
  _emit_event(plugin, "focus");
  return false;
}

gboolean on_window_blur(GtkWidget* widget, GdkEvent* event, gpointer data) {
  WindowManagerPlugin* plugin = WINDOW_MANAGER_PLUGIN(data);
  _emit_event(plugin, "blur");
  return false;
}

gboolean on_window_show(GtkWidget* widget, gpointer data) {
  WindowManagerPlugin* plugin = WINDOW_MANAGER_PLUGIN(data);
  _emit_event(plugin, "show");
  return false;
}

gboolean on_window_hide(GtkWidget* widget, gpointer data) {
  WindowManagerPlugin* plugin = WINDOW_MANAGER_PLUGIN(data);
  _emit_event(plugin, "hide");
  return false;
}

gboolean on_window_resize(GtkWidget* widget, gpointer data) {
  WindowManagerPlugin* plugin = WINDOW_MANAGER_PLUGIN(data);
  _emit_event(plugin, "resize");
  return false;
}

gboolean on_window_move(GtkWidget* widget, GdkEvent* event, gpointer data) {
  WindowManagerPlugin* plugin = WINDOW_MANAGER_PLUGIN(data);
  _emit_event(plugin, "move");
  return false;
}

gboolean on_window_state_change(GtkWidget* widget,
                                GdkEventWindowState* event,
                                gpointer data) {
  WindowManagerPlugin* plugin = WINDOW_MANAGER_PLUGIN(data);
  if (event->changed_mask & GDK_WINDOW_STATE_MAXIMIZED) {
    if (event->new_window_state & GDK_WINDOW_STATE_MAXIMIZED) {
      _emit_event(plugin, "maximize");
    } else {
      _emit_event(plugin, "unmaximize");
    }
  }
  if (event->changed_mask & GDK_WINDOW_STATE_ICONIFIED) {
    if (event->new_window_state & GDK_WINDOW_STATE_ICONIFIED) {
      _emit_event(plugin, "minimize");
    } else {
      _emit_event(plugin, "restore");
    }
  }
  if (event->changed_mask & GDK_WINDOW_STATE_FULLSCREEN) {
    if (event->new_window_state & GDK_WINDOW_STATE_FULLSCREEN) {
      _emit_event(plugin, "enter-full-screen");
    } else {
      _emit_event(plugin, "leave-full-screen");
    }
  }
  return false;
}

void emit_button_release(WindowManagerPlugin* self) {
  auto newEvent = (GdkEventButton*)gdk_event_new(GDK_BUTTON_RELEASE);
  newEvent->x = self->_event_button.x;
  newEvent->y = self->_event_button.y;
  newEvent->button = self->_event_button.button;
  newEvent->type = GDK_BUTTON_RELEASE;
  newEvent->time = g_get_monotonic_time();
  gboolean result;
  g_signal_emit_by_name(self->_event_box, "button-release-event", newEvent,
                        &result);
  gdk_event_free((GdkEvent*)newEvent);
}

gboolean on_event_after(GtkWidget* text_view,
                        GdkEvent* event,
                        WindowManagerPlugin* self) {
  if (event->type == GDK_ENTER_NOTIFY) {
    if (nullptr == self->_event_box) {
      return FALSE;
    }
    if (self->_is_dragging) {
      self->_is_dragging = false;
      emit_button_release(self);
    }
    if (self->_is_resizing) {
      self->_is_resizing = false;
      emit_button_release(self);
    }
  }
  return FALSE;
}

gboolean on_mouse_press(GSignalInvocationHint* ihint,
                        guint n_param_values,
                        const GValue* param_values,
                        gpointer data) {
  WindowManagerPlugin* plugin = WINDOW_MANAGER_PLUGIN(data);
  GdkEventButton* event_button =
      (GdkEventButton*)(g_value_get_boxed(param_values + 1));

  // plugin->_event_button = event_button;

  memset(&plugin->_event_button, 0, sizeof(plugin->_event_button));
  memcpy(&plugin->_event_button, event_button, sizeof(plugin->_event_button));
  return TRUE;
}

void window_manager_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  WindowManagerPlugin* plugin = WINDOW_MANAGER_PLUGIN(
      g_object_new(window_manager_plugin_get_type(), nullptr));

  plugin->registrar = FL_PLUGIN_REGISTRAR(g_object_ref(registrar));

  plugin->window_geometry.min_width = -1;
  plugin->window_geometry.min_height = -1;
  plugin->window_geometry.max_width = G_MAXINT;
  plugin->window_geometry.max_height = G_MAXINT;
  plugin->window_hints = static_cast<GdkWindowHints>(0);

  // Disconnect all delete-event handlers first in flutter 3.10.1, which causes delete_event not working.
  // Issues from flutter/engine: https://github.com/flutter/engine/pull/40033 
  guint handler_id = g_signal_handler_find(get_window(plugin), G_SIGNAL_MATCH_DATA, 0, 0, NULL, NULL, fl_plugin_registrar_get_view(plugin->registrar));
  if (handler_id > 0) {
    g_signal_handler_disconnect(get_window(plugin), handler_id);
  }

  g_signal_connect(get_window(plugin), "delete_event",
                   G_CALLBACK(on_window_close), plugin);
  g_signal_connect(get_window(plugin), "focus-in-event",
                   G_CALLBACK(on_window_focus), plugin);
  g_signal_connect(get_window(plugin), "focus-out-event",
                   G_CALLBACK(on_window_blur), plugin);
  g_signal_connect(get_window(plugin), "show", G_CALLBACK(on_window_show),
                   plugin);
  g_signal_connect(get_window(plugin), "hide", G_CALLBACK(on_window_hide),
                   plugin);
  g_signal_connect(get_window(plugin), "check-resize",
                   G_CALLBACK(on_window_resize), plugin);
  g_signal_connect(get_window(plugin), "configure-event",
                   G_CALLBACK(on_window_move), plugin);
  g_signal_connect(get_window(plugin), "window-state-event",
                   G_CALLBACK(on_window_state_change), plugin);
  g_signal_connect(get_window(plugin), "event-after",
                   G_CALLBACK(on_event_after), plugin);
  find_event_box(plugin, GTK_WIDGET(fl_plugin_registrar_get_view(registrar)));

  g_signal_add_emission_hook(
      g_signal_lookup("button-press-event", GTK_TYPE_WIDGET), 0, on_mouse_press,
      plugin, NULL);

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  plugin->channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "window_manager", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      plugin->channel, method_call_cb, g_object_ref(plugin), g_object_unref);

  g_object_unref(plugin);
}
