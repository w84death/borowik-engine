# P1X Zig Engine

Simple Zig engine project using the `fenster` software renderer.

## Run
```
zig build run
```

## Build Small Binary

Host Linux -> **Linux 64**
```
zig build \
  -Doptimize=ReleaseSmall \
  upx
```

Host Linux -> **Windows 32**
``` 
zig build \
  -Dtarget=x86-windows \
  -Doptimize=ReleaseSmall \
  upx
```
