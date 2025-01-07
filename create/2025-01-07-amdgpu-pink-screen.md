---
thumbnailUrl: "/articles/assets/2025-01-07-amdgpu-pink-screen/thumbnail.jpg"
thumbnailTitle: "Icon showing the fixed screen"
structuredData: {
    "@context": "https://schema.org",
    "@type": "Article",
    author: { 
        "@type": "Person", 
        "name": "Michael Rommel",
        "url": "https://michaelrommel.com/info/about",
        "image": "https://avatars.githubusercontent.com/u/919935?s=100&v=4"
    },
    "dateModified": "2025-01-07T17:21:42+01:00",
    "datePublished": "2023-02-20T00:00:00+01:00",
    "headline": "AMD GPU Pink Screen Artifact",
    "abstract": "How to fix a pink screen displayed by an integrated AMD GPU."
}
tags: ["new", "create", "computer", "AMD", "pink screen"]
published: true
---
# AMDGPU displays wrong colours

## Symptom

After installation of the non-free debian firmware for the internal AMD GPU that is inside the Ryzen 5600G processor, one of my screens showed a bright pink background instead of black. I switched cables and finally could hook up a windows laptop to the screen and verify that the hardware still was functioning properly and the fault was somewhere within the OS/driver.

## Reason

After searching some time, the reason seemed to be that the GPU selects the wrong pixel formats on the HDMI connector from the supported pixel formats that the monitor advertises.

On Windows AMD realized that and provides a utility program that allows manual overrides of the format. Under Linux not so much.

## Solution

The Linux kernel accepts arguments to override the monitor-provided EDID data with a new one. This new EDID file needs to then no longer advertise the faulty pixel formats.

A program called `wxedid` can be used to manipulate the edid information.

I followed those steps, that were mentioned in several articles around the internet, e.g. [here](https://askubuntu.com/questions/1438949/how-to-change-display-pixel-format-from-ycbcr-444-to-full-rgb-444)

First I needed to find the correct edid information:

```
$ find /sys/devices/ -name edid
/sys/devices/pci0000:00/0000:00:08.1/0000:0b:00.0/drm/card0/card0-HDMI-A-1/edid
/sys/devices/pci0000:00/0000:00:08.1/0000:0b:00.0/drm/card0/card0-HDMI-A-2/edid
/sys/devices/pci0000:00/0000:00:08.1/0000:0b:00.0/drm/card0/card0-DP-1/edid
```

I then copied the kernel information to a new file

```
$ cp /sys/devices/pci0000:00/0000:00:08.1/0000:0b:00.0/drm/card0/card0-HDMI-A-1/edid HDMI-A-1-RGB.edid.bin
```

I used wxedid to modify this file:

1. Find SPF: Supported features -> vsig_format -> replace 0b01 wih 0b00 ![](/articles/assets/2025-01-07-amdgpu-pink-screen/screenshot-1.png)
2. Find CHD: CEA-861 header -> change the value of YCbCr420 and YCbCr444 to 0 ![](/articles/assets/2025-01-07-amdgpu-pink-screen/screenshot-2.png) Take note of the checksum displayed at the end of the table
3. Recalculate the checksum: Options > Recalc Checksum and also reparse the EDID buffer ![](/articles/assets/2025-01-07-amdgpu-pink-screen/screenshot-3.png) The checksum should now have changed

Save the file and activate this configuration:

1. Re-locate the file to a standard directory

```
$ sudo mkdir /lib/firmware/edid; 
$ sudo mv HDMI-A-1-RGB.edid.bin /lib/firmware/edid
```

1. Edit the grub config `/etc/default/grub` and add the file with the new EDID information to the kernel commandline parameter. The parameter should specify the HDMI port identifier as first part of the argument where the monitor is connected. It should be the same, as where you located the kernel’s edid information:

```
GRUB_CMDLINE_LINUX="drm.edid_firmware=HDMI-A-1:edid/HDMI-A-1-RGB.edid.bin"
```

1. Update the grub configuration and the initramfs

```
$ sudo update-grub
$ sudo update-initramfs -u
```

1. reboot
2. Observe, if the updated information took effect by running `dmesg`. In the output there should be lines indicating the kernel command line and then later that the EDID was used:

```
[    0.000000] Command line: BOOT_IMAGE=/boot/vmlinuz-6.0.0-0.deb11.6-amd64 root=UUID=8f76f48b-e732-4f64-a31e-cfed0ad3efcd ro drm.edid_firmware=HDMI-A-1:edid/HDMI-A-1-RGB.edid.bin
...
[   11.584426] platform HDMI-A-1: firmware: direct-loading firmware edid/HDMI-A-1-RGB.edid.bin
[   11.584456] [drm] Got external EDID base block and 1 extension from "edid/HDMI-A-1-RGB.edid.bin" for connector "HDMI-A-1"
```

If everything went right, the colour issue should now be resolved. Please note that the numbering of the kernel and the numbering of `xrandr` are not the same! The kernel’s HDMI-A-1 shows up in xrandr as HDMI-A-0. So if the fix doesn’t work, it is likely that you have used the wrong number.
