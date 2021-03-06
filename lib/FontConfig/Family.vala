/* Family.vala
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

    /* Most common font styles, we try to select one of these if possible */
    public const string [] DEFAULT_VARIANTS = {
        "Regular",
        "Roman",
        "Medium",
        "Normal",
        "Book"
    };

    public int sort_families (Family a, Family b) {
        return natural_cmp(a.name, b.name);
    }

    /**
     * Family:
     */
    public class Family : Cacheable {

        public string name { get; protected set; }
        /**
         * Family:description:
         *
         * A valid #Pango.FontDescription string for this
         */
        public string description { get; protected set; }
        public bool has_bold { get; private set; default = false; }
        public bool has_italic { get; private set; default = false; }
        public Gee.HashMap <string, Font> faces { get; protected set; }

        public Family (string name) {
            this.name = description = name;
            this.init();
        }

        protected virtual void init () {
            faces = new Gee.HashMap <string, Font> ();
            foreach (var face in list_fonts(name)) {
                faces[face.style] = face;
                if (((Weight) face.weight) >= Weight.DEMIBOLD)
                    has_bold = true;
                if (((Slant) face.slant) != Slant.ROMAN)
                    has_italic = true;
            }
            return;
        }

        /**
         * list_faces:
         *
         * @return      sorted #Gee.ArrayList of #FontConfig.Font in this
         */
        public Gee.ArrayList <Font> list_faces () {
            var fontlist = new Gee.ArrayList <Font> ();
            fontlist.add_all(faces.values);
            fontlist.sort((CompareDataFunc) sort_fonts);
            return fontlist;
        }

        /**
         * get_default_variant:
         *
         * @return      the default #FontConfig.Font for this
         */
        public Font get_default_variant () {
            var fontlist = list_faces();
            /* Try to find default variant */
            foreach (Font font in fontlist) {
                string style = font.description;
                if (style == name)
                    return font;
                foreach (var variant in DEFAULT_VARIANTS)
                    if (style.contains(variant))
                        return font;
            }
            /* Better than nothing */
            return fontlist[0];
        }

        public override bool deserialize_property (string prop_name,
                                                        out Value val,
                                                        ParamSpec pspec,
                                                        Json.Node node) {
            if (pspec.value_type == typeof(Gee.HashMap)) {
                val = Value(pspec.value_type);
                var facemap = new Gee.HashMap <string, Font> ();
                node.get_object().foreach_member((obj, name, node) => {
                    facemap[name] = (Font) Json.gobject_deserialize(typeof(Font), node);
                });
                val.set_object(facemap);
                return true;
            } else
                return base.deserialize_property(prop_name, out val, pspec, node);
        }

        public override Json.Node serialize_property (string prop_name,
                                                               Value val,
                                                               ParamSpec pspec) {
            if (pspec.value_type == typeof(Gee.HashMap)) {
                var node = new Json.Node(Json.NodeType.OBJECT);
                var obj = new Json.Object();
                foreach (Font face in faces.values)
                    obj.set_member(face.style.escape(""), Json.gobject_serialize(face));
                node.set_object(obj);
                return node;
            } else
                return base.serialize_property(prop_name, val, pspec);
        }

    }

}

