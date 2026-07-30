"""
Draw Arabic (or Latin) text into a Pillow image with real OpenType shaping.

Why not arabic-reshaper + python-bidi: that pair rewrites text into the legacy
Arabic Presentation Forms block (U+FE70-U+FEFF) and relies on the font mapping
those codepoints. Cairo does not - it ships base Arabic letters and does its
joining through OpenType GSUB, so the presentation-form approach renders the
missing ones as tofu (U+FE8D, U+FE95, U+FEAD were the visible casualties).

So: shape with HarfBuzz, which applies the font's own GSUB/GPOS and returns
glyph ids with positions, then rasterise those glyph ids with FreeType. This
is what a real text stack does, and it works for any font.
"""

from PIL import Image
import freetype
import uharfbuzz as hb


class ShapedFont:
    def __init__(self, path, size):
        self.size = size

        with open(path, "rb") as handle:
            data = handle.read()
        self.hb_font = hb.Font(hb.Face(data))
        self.hb_font.scale = (size * 64, size * 64)

        self.ft_face = freetype.Face(path)
        self.ft_face.set_char_size(size * 64)

    def shape(self, text, direction="rtl", script="Arab", language="ar"):
        buf = hb.Buffer()
        buf.add_str(text)
        buf.direction = direction
        buf.script = script
        buf.language = language
        hb.shape(self.hb_font, buf, {"kern": True, "liga": True})
        return buf.glyph_infos, buf.glyph_positions

    def measure(self, text, **kwargs):
        _, positions = self.shape(text, **kwargs)
        return sum(p.x_advance for p in positions) / 64.0

    def draw(self, image, xy, text, fill, **kwargs):
        """Draw `text` with its left edge at xy[0] and baseline at xy[1]."""
        infos, positions = self.shape(text, **kwargs)

        pen_x, pen_y = xy[0] * 64.0, xy[1] * 64.0

        for info, pos in zip(infos, positions):
            self.ft_face.load_glyph(info.codepoint, freetype.FT_LOAD_RENDER)
            slot = self.ft_face.glyph
            bitmap = slot.bitmap

            if bitmap.width and bitmap.rows:
                glyph = Image.frombytes(
                    "L", (bitmap.width, bitmap.rows), bytes(bitmap.buffer)
                )
                left = int((pen_x + pos.x_offset) / 64.0) + slot.bitmap_left
                top = int((pen_y + pos.y_offset) / 64.0) - slot.bitmap_top

                colour = Image.new("RGBA", glyph.size, fill)
                image.paste(colour, (left, top), glyph)

            pen_x += pos.x_advance
            pen_y += pos.y_advance

    def ascent(self):
        return self.ft_face.size.ascender / 64.0
