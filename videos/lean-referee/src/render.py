"""python3 render.py v001 [scene ...]  -> renders/<ver>/scenes/*.mp4, then full.mp4 with music"""
import os, sys, subprocess, multiprocessing as mp
from lib import W, H, FPS
import scenes, scenes2
SC = scenes.SCENES + scenes2.SCENES

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def render_scene(args):
    ver, name, t0, t1 = args
    fn = dict((s[0], s[3]) for s in SC)[name]
    out = os.path.join(ROOT, 'renders', ver, 'scenes', name + '.mp4')
    tmp = out + '.tmp.mp4'
    n0, n1 = round(t0 * FPS), round(t1 * FPS)
    p = subprocess.Popen(['ffmpeg', '-v', 'error', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}',
                          '-r', str(FPS), '-i', '-', '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '18',
                          '-pix_fmt', 'yuv420p', tmp], stdin=subprocess.PIPE)
    for n in range(n0, n1):
        p.stdin.write(fn(n / FPS).tobytes())
    p.stdin.close(); p.wait()
    os.replace(tmp, out)
    return name, n1 - n0

if __name__ == '__main__':
    ver = sys.argv[1]
    only = sys.argv[2:]
    os.makedirs(os.path.join(ROOT, 'renders', ver, 'scenes'), exist_ok=True)
    jobs = [(ver, s[0], s[1], s[2]) for s in SC if not only or s[0] in only]
    # split long scenes is unnecessary at this length; longest first for balance
    jobs.sort(key=lambda j: j[2] - j[3])
    with mp.Pool(4) as pool:
        for r in pool.imap_unordered(render_scene, jobs):
            print('done', r, flush=True)
    d = os.path.join(ROOT, 'renders', ver)
    names = [s[0] for s in SC if os.path.exists(os.path.join(d, 'scenes', s[0] + '.mp4'))]
    with open(os.path.join(d, 'list.txt'), 'w') as f:
        for nme in names:
            f.write(f"file 'scenes/{nme}.mp4'\n")
    end = SC[[s[0] for s in SC].index(names[-1])][2]
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'concat', '-safe', '0', '-i', os.path.join(d, 'list.txt'),
                    '-c', 'copy', os.path.join(d, 'video.mp4')], check=True)
    music = os.path.join(ROOT, 'audio', 'score.wav')
    af = 'afade=t=out:st=%.2f:d=0.8' % (end - 0.8) if end < 150 else 'anull'
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', os.path.join(d, 'video.mp4'), '-i', music, '-t', f'{end:.3f}',
                    '-map', '0:v', '-map', '1:a', '-c:v', 'copy', '-af', af, '-c:a', 'aac', '-b:a', '192k',
                    '-movflags', '+faststart', os.path.join(d, 'full.mp4')], check=True)
    print('wrote', os.path.join(d, 'full.mp4'))
