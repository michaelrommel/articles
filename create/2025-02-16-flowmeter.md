---
thumbnailUrl: "/articles/assets/2025-02-16-flowmeter/thumbnail.png"
thumbnailTitle: "Image showing a spinning disc driven by a water flow"
structuredData: {
    "@context": "https://schema.org",
    "@type": "Article",
    author: {
        "@type": "Person",
        "name": "Michael Rommel",
        "url": "https://michaelrommel.com/info/about",
        "image": "https://avatars.githubusercontent.com/u/919935?s=100&v=4"
    },
    "dateModified": "2025-02-16T15:52:53+01:00",
    "datePublished": "2025-02-16T15:53:09+01:00",
    "headline": "Designing a Watercooler Flowmeter",
    "abstract": "Create an inexpensive flowmeter for a watercooling system using off-the-shelf components and 3D printing."
}
tags: ["new", "create", "hardware", "watercooling", "flowmeter"]
published: true
---

# A Watercooling Flowmeter

## Motivation

I use watercooled systems since many years now because they provide good cooling with
minimal noise. The downside is the regular maintenance that goes along with it. During one
of my latest disassemblies my original flowmeter broke and the replacements I tried to
find online all kinds of downsides. Either they were only showing a rotating wheel, no
electronics whatsoever, or they show it on a display, with no interfaces to read out the
values or they only work with proprietory control systems or were heavily overpriced.

I wanted a simple solution, that can be hooked up to any standard PC fan header on any
motherboard and where I can use `sensors` under Linux to get the current RPM value.


## First Iterations

I started by purchasing an inexpensive mechanical flowmeter, that only had a spinning
star-shaped plastic wheel inside an aluminium enclosure. I did not want to deal right now
with machining the part, cutting threads and sealing all up.

![Flowmeter Original](/articles/assets/2025-02-16-flowmeter/flowmeter-original.jpg)

First I tried glueing magnets in between the fins of the propeller, but somehow the
propeller would not even start under normal circumstances and flow. So I took out
everything and replaced it with a 3D printed mechanism, where the spinning disc was much
smaller.

![Iterations](/articles/assets/2025-02-16-flowmeter/flowmeter-variants.jpg)

The first iteration started with a narrow hole to increase the flow rate at this point and
make the disc spin fast to get good readings on the sensors. I took the dimensions from
the old sensor which were roughly a 4mm diameter hole and a small disc with a ø6mm x 2mm
magnet. This design worked, but the magnet was too weak to be deteced through the
plexiglass cover plate.

The next iteration increased the disc diameter and magnet thickness. 

::svelte[]{ componentname="StlViewer" file="flowmeter-v1.gltf" dpr=true inertia=1200}

This worked well for a couple of weeks, then the rotation stopped again.


## Further Iterations

When disassembling the system, I found some particles that had accumulated on top of the
magnet and suspected that those were rubbing against the lid and caused the disc to stop 
spinning. Also I wanted to have as little flow restriction as possible, so I decided to
make the inflow aperture bigger, extending its height. To avoid rubbing against the top, I
made a little ring, that keeps the larger disc at a small distance from the top glass.

I wanted to use two magnets to counterbalance the disc and stronger magnets need to be
further apart in order for the hall sensor to register them individually as singular
pulses. It again would not start up, it seems the inlets were not off-centered enough, so
I started with some experiments, changing the directions where the inflow hits the
propeller, switching curved blades with straight ones and also from 6 to 8 blades. Finally
I have now a version that starts up reliably.

It now also covers completely the magnet and has an second color segment printed right
into it, that helps with easy identifying if something is stuck or turns too slowly.

::svelte[]{ componentname="StlViewer" file="flowmeter-v2.gltf" dpr=true inertia=1200}


## Sensor Mount

For the sensor I used a simple hall effect sensor A3144, which costs less than 10ct and a
10k Ohm resistor. The signal wire that goes to the mainboards tacho pin is connected to
pin 3 of the hall sensor and via that 10k resistor to the supply voltage, essentially a
pull-up resistor. I 3D printed the mount that slips right onto the enclosure and can be
kept in place with a bit of tape. I could have made latches or other fancy shapes, but
felt it was not worth the iteration.

::svelte[]{ componentname="StlViewer" file="flowmeter-v2-sensor.gltf" dpr=true inertia=1200}


## Final Tests

Here is how it looks in its final design and some images of testing it with a small
portable oscilloscope.

![Iterations](/articles/assets/2025-02-16-flowmeter/flowmeter-final.jpg)

![Iterations](/articles/assets/2025-02-16-flowmeter/flowmeter-sensor.jpg)

![Iterations](/articles/assets/2025-02-16-flowmeter/flowmeter-testsetup.jpg)

![Iterations](/articles/assets/2025-02-16-flowmeter/flowmeter-scope.jpg)

The equivalent RPM of the sensor is round about 900RPM, because there are two magnets in
the disc.


## Conclusion

Overall I am happy with the design. It does not considerably block the water flow and
provides compatibility with the standard mainboard headers. It can therefore easily be
integrated into Grafana for a dashboard view of the system's health. The costs were --
even considering all the iterations I went through -- less than 16 EUR.

It will be interesting to see how well it will perform, if I switch to hard tubings in
the next build. The design files for the 3d prints can be requested
[here](https://github.com/michaelrommel/articles/discussions/3).

