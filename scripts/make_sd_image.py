"""Create a NEW FAT16 image containing four contiguous BMPs. Never writes a device."""
from pathlib import Path
import argparse
import struct

PARTITION_LBA = 2048
VOLUME_SECTORS = 131072
FAT_SECTORS = 128
ROOT_SECTORS = 32
DATA_LBA = PARTITION_LBA + 1 + 2*FAT_SECTORS + ROOT_SECTORS
CLUSTER_BYTES = 4096

def demo_bmp(index,native=False):
    w,h=(640,480) if native else [(640,480),(320,240),(800,600),(641,479)][index]
    rows = []
    for y in range(h-1,-1,-1):
        rows.append(bytes(channel for x in range(w) for channel in
                    ((x//80*32+index*40)%256, (y*255//(h-1)), (x*255//(w-1))))+bytes((-w*3)%4))
    pixels = b''.join(rows)
    return (struct.pack('<2sIHHI',b'BM',54+len(pixels),0,0,54)+
            struct.pack('<IiiHHIIiiII',40,w,h,1,24,0,len(pixels),2835,2835,0,0)+pixels)

def validate_bmp(data):
    if len(data)<54 or data[:2]!=b'BM': raise ValueError('Not a BMP')
    size,offset = struct.unpack_from('<I',data,2)[0],struct.unpack_from('<I',data,10)[0]
    dib,w,h,planes,bpp,compression=struct.unpack_from('<IiiHHI',data,14)
    if not (1<=w<=1920 and 1<=h<=1440 and (planes,bpp,compression)==(1,24,0) and 40<=dib<=124):
        raise ValueError('Requires bottom-up 1..1920 x 1..1440 RGB888 BI_RGB BMP')
    image_bytes=((w*3+3)&~3)*h
    if not max(54,14+dib)<=offset<=4096 or not offset+image_bytes<=size<=offset+image_bytes+4096 or size!=len(data):
        raise ValueError('Unsupported BMP offset/size')

def make_image(images):
    if len(images)!=4: raise ValueError('Baseline scanner expects exactly four images')
    for data in images: validate_bmp(data)
    image=bytearray((PARTITION_LBA+VOLUME_SECTORS)*512)
    image[446:462]=struct.pack('<B3sB3sII',0,b'\xfe\xff\xff',6,b'\xfe\xff\xff',PARTITION_LBA,VOLUME_SECTORS)
    image[510:512]=b'\x55\xaa'
    boot=bytearray(512)
    boot[:11]=b'\xeb\x3c\x90FPGA2026'
    struct.pack_into('<HBHBHHBHHHII',boot,11,512,CLUSTER_BYTES//512,1,2,512,0,0xf8,FAT_SECTORS,63,255,PARTITION_LBA,VOLUME_SECTORS)
    boot[36:39]=b'\x80\x00\x29'
    struct.pack_into('<I',boot,39,0x20261009)
    boot[43:54]=b'FPGA MEDIA '
    boot[54:62]=b'FAT16   '
    boot[510:512]=b'\x55\xaa'
    image[PARTITION_LBA*512:(PARTITION_LBA+1)*512]=boot
    fat=bytearray(FAT_SECTORS*512)
    struct.pack_into('<HH',fat,0,0xfff8,0xffff)
    root_lba=PARTITION_LBA+1+2*FAT_SECTORS
    cluster=2
    for index,data in enumerate(images):
        count=(len(data)+CLUSTER_BYTES-1)//CLUSTER_BYTES
        if DATA_LBA*512+(cluster-2+count)*CLUSTER_BYTES > min(len(image),131072*512):
            raise ValueError('Images exceed the scanner/card data range')
        for c in range(cluster,cluster+count):
            struct.pack_into('<H',fat,c*2,0xffff if c==cluster+count-1 else c+1)
        entry=bytearray(32)
        entry[:11]=f'PIC{index+1:05d}BMP'.encode()
        entry[11]=0x20
        struct.pack_into('<HI',entry,26,cluster,len(data))
        image[root_lba*512+index*32:root_lba*512+(index+1)*32]=entry
        start=DATA_LBA*512+(cluster-2)*CLUSTER_BYTES
        image[start:start+len(data)]=data
        cluster+=count
    for copy in range(2):
        start=(PARTITION_LBA+1+copy*FAT_SECTORS)*512
        image[start:start+len(fat)]=fat
    return image

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('output',type=Path)
    p.add_argument('bmp',type=Path,nargs='*')
    p.add_argument('--native',action='store_true',help='Generate four 640x480 images for profiles without scaling')
    args=p.parse_args()
    if args.output.exists(): raise SystemExit('Refusing to overwrite existing output')
    if args.output.suffix.lower()!='.img': raise SystemExit('Output must be a regular .img file')
    images=[f.read_bytes() for f in args.bmp] if args.bmp else [demo_bmp(i,native=args.native) for i in range(4)]
    image=make_image(images)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    with args.output.open('xb') as f:f.write(image)
    print(f'Created {args.output}: {len(image)} bytes, four contiguous BMPs, FAT16')
    print('No physical card was accessed. Flashing a card requires separately confirming the target device.')

if __name__=='__main__':main()
