# KLayout batch script: render the final GDS to PNG images
#   klayout -b -r render_layout.py -rd gds=<file> -rd lyp=<file> -rd out=<prefix>
import pya

lv = pya.LayoutView()
lv.set_config("background-color", "#000000")
lv.set_config("grid-visible", "false")
lv.set_config("text-visible", "false")
idx = lv.load_layout(gds, 0)
if lyp:
    lv.load_layer_props(lyp)
lv.max_hier()

# full chip
lv.zoom_fit()
lv.save_image(out + "_layout.png", 2400, 2400)

# zoomed view of the core centre (standard cells + routing)
box = lv.box()
cx, cy = box.center().x, box.center().y
w, h = box.width() * 0.18, box.height() * 0.18
lv.zoom_box(pya.DBox(cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2))
lv.save_image(out + "_layout_zoom.png", 2400, 2400)
