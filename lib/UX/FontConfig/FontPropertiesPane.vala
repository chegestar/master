/* FontPropertiesPane.vala
 *
 * Copyright (C) 2009 - 2016 Jerry Casiano
 *
 * This file is part of Font Manager.
 *
 * Font Manager is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Font Manager is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Font Manager.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Author:
 *        Jerry Casiano <JerryCasiano@gmail.com>
*/

namespace FontConfig {

    /**
     * FontPropertiesPane:
     *
     * Preference pane allowing configuration of FontConfig rendering properties
     */
    public class FontPropertiesPane : Gtk.ScrolledWindow {

        public FontProperties properties { get; private set; }

        Gtk.Grid grid;
        Gtk.Revealer hinting_options;
        Gtk.Grid hinting_options_grid;
        Gtk.Expander expander;
        Gtk.CheckButton autohint;
        OptionScale hintstyle;
        LabeledSwitch antialias;
        LabeledSwitch hinting;
        LabeledSwitch embeddedbitmap;
        SizeOptions size_options;

        public FontPropertiesPane () {
            grid = new Gtk.Grid();
            properties = new FontProperties();
            antialias = new LabeledSwitch(_("Antialias"));
            hinting = new LabeledSwitch(_("Hinting"));
            autohint = new Gtk.CheckButton.with_label(_("Enable Autohinter"));
            hinting_options = new Gtk.Revealer();
            hinting_options_grid = new Gtk.Grid();
            hinting_options_grid.margin = 36;
            string [] hintstyles = {};
            for (int i = 0; i < 4; i++)
                hintstyles += ((HintStyle) i).to_string();
            hintstyle = new OptionScale(_("Hinting Style"), hintstyles);
            embeddedbitmap = new LabeledSwitch(_("Use Embedded Bitmaps"));
            size_options = new SizeOptions();
            expander = new Gtk.Expander(_(" Size Restrictions "));
            expander.notify["expanded"].connect(() => {
                if (expander.expanded)
                    expander.set_label(_(" Apply settings to point sizes "));
                else
                    expander.set_label(_(" Size Restrictions "));
            });
            bind_properties();
            pack_components();
            grid.foreach((w) => { w.get_style_context().add_class(Gtk.STYLE_CLASS_VIEW); });
            grid.get_style_context().add_class(Gtk.STYLE_CLASS_VIEW);
            get_style_context().add_class(Gtk.STYLE_CLASS_VIEW);
            set_size_request(450, 450);
        }

        public override void show () {
            antialias.show();
            hinting.show();
            autohint.show();
            hintstyle.show();
            hinting_options_grid.show();
            hinting_options.show();
            embeddedbitmap.show();
            size_options.show();
            expander.show();
            grid.show();
            base.show();
            update_sensitivity();
            return;
        }

        void pack_components () {
            grid.attach(antialias, 0, 0, 2, 1);
            grid.attach(hinting, 0, 1, 2, 1);
            hinting_options_grid.attach(autohint, 0, 0, 2, 1);
            hinting_options_grid.attach(hintstyle, 0, 1, 2, 1);
            hinting_options.add(hinting_options_grid);
            grid.attach(hinting_options, 0, 2, 2, 1);
            grid.attach(embeddedbitmap, 0, 3, 2, 1);
            expander.add(size_options);
            grid.attach(expander, 0, 4, 2, 1);
            add(grid);
            return;
        }

        void bind_properties () {
            properties.bind_property("antialias", antialias.toggle, "active", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);
            properties.bind_property("hinting", hinting.toggle, "active", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);
            properties.bind_property("autohint", autohint, "active", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);
            properties.bind_property("hintstyle", hintstyle.scale.adjustment, "value", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);
            properties.bind_property("embeddedbitmap", embeddedbitmap.toggle, "active", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);
            properties.bind_property("less", size_options.less, "value", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);
            properties.bind_property("more", size_options.more, "value", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);
            hinting.toggle.bind_property("active", hinting_options, "reveal-child", BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE);
            properties.notify["font"].connect(() => { update_sensitivity(); });
            properties.notify["family"].connect(() => { update_sensitivity(); });
            return;
        }

        void update_sensitivity () {
            if (properties.font == null && properties.family == null)
                expander.hide();
            else
                expander.show();
            return;
        }

        class SizeOptions : Gtk.Grid {

            public LabeledSpinButton less { get; private set; }
            public LabeledSpinButton more { get; private set; }

            public SizeOptions () {
                less = new LabeledSpinButton(_("Smaller than"), 0, 96, 0.5);
                more = new LabeledSpinButton(_("Larger than"), 0, 96, 0.5);
                attach(less, 0, 0, 1, 1);
                attach(more, 1, 0, 1, 1);
            }

            public override void show () {
                less.show();
                more.show();
                base.show();
            }

        }

    }

}
