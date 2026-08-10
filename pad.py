from PIL import Image

img = Image.open('assets/images/logo.png')
w, h = img.size
new_w = int(w * 1.5)
new_h = int(h * 1.5)
new_img = Image.new('RGBA', (new_w, new_h), (255, 255, 255, 0))
new_img.paste(img, (int((new_w - w) / 2), int((new_h - h) / 2)))
new_img.save('assets/images/logo_splash.png')
