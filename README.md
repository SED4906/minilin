# Minilin
Builds a musl+busybox+dropbear ISO.
- Run `./build.sh` to begin.
- - It will pull the files it needs if they aren't already downloaded.
- - Output is `minilin.iso`, default hostname is `minilin`
- - A file named `authorized_keys` in the directory the script is run from will be copied into the built ISO's rootfs, if it exists.