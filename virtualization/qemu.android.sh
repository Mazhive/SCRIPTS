#!/bin/bash
qemu-system-x86_64 -enable-kvm -m 4048 -smp 2 -cpu host -soundhw es1370 -device virtio-mouse-pci -device virtio-keyboard-pci -serial mon:stdio -boot menu=on -net nic -net user,hostfwd=tcp::5555-:22 -device virtio-vga,virgl=on -display gtk,gl=on -hda ~/androidx86_hda.img -cdrom /mnt/VG_00/PUBLIC-LIBRARY/OS/ANDROID/android-x86_64-8.1-r6.iso
