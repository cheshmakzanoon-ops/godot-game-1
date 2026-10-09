#!/usr/bin/env python3
"""Draw an original flat-printmaking launcher icon; deterministic Pillow tool."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from math import sin, cos, pi

ROOT = Path(__file__).resolve().parents[1]
SIZE = 512
SCALE = 3
S = SIZE * SCALE
DARK = '#101928'
PAPER = '#f7ead7'
COPPER = '#dc855e'
GOLD = '#d0ad6c'

def main():
    image = Image.new('RGB', (S, S), DARK)
    d = ImageDraw.Draw(image)
    d.rectangle((28*SCALE, 28*SCALE, 484*SCALE, 484*SCALE), outline='#4a5261', width=2*SCALE)
    xc = yc = S//2
    for r in range(190*SCALE, 62*SCALE, -8*SCALE):
        d.ellipse((xc-r,yc-r,xc+r,yc+r), outline=('#2b3543' if (r//SCALE//8)%2 else '#263040'), width=2*SCALE)
    d.ellipse((xc-196*SCALE,yc-196*SCALE,xc+196*SCALE,yc+196*SCALE), outline=GOLD, width=5*SCALE)
    for i in range(12):
        theta = i*2*pi/12 -.2
        r1=190*SCALE
        r2=224*SCALE
        x1=xc+int(r1*cos(theta)); y1=yc+int(r1*sin(theta))
        x2=xc+int(r2*cos(theta)); y2=yc+int(r2*sin(theta))
        d.line((x1,y1,x2,y2),fill=PAPER if i%2 else GOLD,width=7*SCALE)
        sr=11*SCALE
        d.ellipse((x1-sr,y1-sr,x1+sr,y1+sr),fill=COPPER if i%3 else GOLD)
    d.ellipse((xc-78*SCALE,yc-78*SCALE,xc+78*SCALE,yc+78*SCALE),fill=COPPER)
    d.ellipse((xc-67*SCALE,yc-67*SCALE,xc+67*SCALE,yc+67*SCALE),fill=PAPER)
    font_path='/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
    font=ImageFont.truetype(font_path, 57*SCALE)
    bbox=d.textbbox((0,0),'NB',font=font)
    d.text((xc-(bbox[2]-bbox[0])/2, yc-(bbox[3]-bbox[1])/2-bbox[1]), 'NB', font=font,fill=DARK)
    d.ellipse((xc-8*SCALE,yc+48*SCALE,xc+8*SCALE,yc+64*SCALE),fill=COPPER)
    image=image.resize((SIZE,SIZE),Image.Resampling.LANCZOS)
    image.save(ROOT/'art/icon.png')
    image.resize((432,432),Image.Resampling.LANCZOS).save(ROOT/'art/icon_adaptive.png')
    print('Wrote 512px and 432px icons')


if __name__=='__main__':
    main()
