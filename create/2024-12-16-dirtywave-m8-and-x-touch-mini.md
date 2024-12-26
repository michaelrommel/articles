---
thumbnailUrl: "/articles/assets/2024-12-16-dirtywave-m8-and-x-touch-mini/thumbnail.png"
thumbnailTitle: "Icon showing the M8 interface"
structuredData: {
    "@context": "https://schema.org",
    "@type": "Article",
    author: { 
        "@type": "Person", 
        "name": "Michael Rommel",
        "url": "https://michaelrommel.com/info/about",
        "image": "https://avatars.githubusercontent.com/u/919935?s=100&v=4"
    },
    "dateModified": "2024-12-26T17:37:02+01:00",
    "datePublished": "2024-12-26T17:12:02+01:00",
    "headline": "Controlling the Dirtywave M8 with the Behringer X-Touch Mini",
    "abstract": "Set up the X-Touch mini and control the Dirtywave M8 to start/stop song rows, send mutes and solos and change arbitrary parameters usinge MIDI CC commands."
}
tags: ["new", "create", "music"]
published: true
---

# Controlling the Dirtywave M8 with the Behringer X-Touch Mini

## Motivation

In order to make it easier for me to tweak the parameters of instruments during
creation, I wanted to purchase a control surface like the Novation
Launchpad Pro, as this is now supported by the M8. Then I remembered that I
had used a Behringer X-Touch Mini with Lightroom some time ago. I no longer
use Lightroom, due to Adobe's subscription absurdity. So this was a good time
to get this going with the M8.


## The Basics

I wanted to use the Layer A for sound design and tweaking parameters during
instrument creation and Layer B for controlling the M8 when playing back
songs and tweak more runtime parameters, like filter cutoffs etc.

I felt that there is a distince lack of written documentation for the
correct MIDI parameters the M8 supports. Some bits and pieces I could
gather from Discord, the ChangeLog of the binary releases and comments on
YouTube videos.

In order to have more control over the values sent to the device, I
installed a suite of programs from github. Those are SendMidi, ReceiveMidi
and ShowMidi from [gbevin](https://github.com/gbevin/).

The SendMidi program allows you to specify the exact device to send command
or notes to, eliminating sources of error (we'll come to that later). Here
is a simple list of commands to determine connected MIDI devices and send a
play/stop command for the song row 0 to the M8.

```console
 sendmidi list
UMC1820
M8
X-TOUCH MINI
Logic Pro Virtual In
 sendmidi dev m8 ch 10 on 0 1
 sendmidi dev m8 ch 10 off 0 1
```

Using the command `sendmidi dev m8 start` would also start the song, but I
think it uses a different, generic MCC command (Machine Control Command),
but I am not absolutely sure about that.


## Configuring the Dirtywave M8

I specifically set the channels available for configuration on the M8 to
certain values and not use "All". My settings for designing an instument
are as follows:

![M8 MIDI Settings](/articles/assets/2024-12-16-dirtywave-m8-and-x-touch-mini/m8.png)

This way I can use channel 11 for all CC messages, that can be used to
control instument parameters, like filter cutoff, reverb, delay, modulation
params etc. This channel also receives the notes for mute and solo
commands.

The "songrow cue ch" is the channel, which can trigger the playback of a
certain row of a song.


## Configuring the X-Touch Mini

Unfortunately there is no macOS/Linux version of the control program for
the X-Touch mini, so this has to be done on a Windows machine. The program
can get the current settings from the hardware device or a file and vice
versa. Layer A and B are stored in different files.

The encoder knobs at the top are configurable in how the LED ring
surrounding them shall react. The parameter range can be defined with low
and high thresholds, and the M8 automatically translates the 0 -- 127 range
into a full 0x00 -- 0xff range.


### Layer A

On Layer A I have configured the four left encoders as "Fan" and the four
right encoders as "Trim". Therefore the right ones can be used primarily
for parameters where the default value is 0x80 and the visual indicator
then shows lit LEDs from 12 o'clock to either the left or the right. The
left ones light up from 7 o'clock to 5 o'clock.

![Layer A Encoders](/articles/assets/2024-12-16-dirtywave-m8-and-x-touch-mini/layer-a-encoders.png)

The encoders also act as buttons. I use them for soloing a track,
while tweaking it. Setting all buttons as toggles was the easiest to work
with and not need to hold down a button.

![Layer A Buttons Top](/articles/assets/2024-12-16-dirtywave-m8-and-x-touch-mini/layer-a-buttons-top.png)

The button rows below the encoders are used to mute the corresponding
track.

![Layer A Buttons Bottom](/articles/assets/2024-12-16-dirtywave-m8-and-x-touch-mini/layer-a-buttons-bottom.png)

The lower button row in Layer-A is set up to emit also control messages and
I set the values to switch between a low and a high value in different
extremes. This allows me to map those to parameters, where I want to easily
hear how a drastic change of that parameter affects the sound.


### Layer B

Layer B is more of a performance oriented Layer. The encoders are all set
to "Single" and I assign them to the parameter that is most important for
that track.

![Layer B Encoders](/articles/assets/2024-12-16-dirtywave-m8-and-x-touch-mini/layer-b-encoders.png)

The encoder buttons act the same as in Layer A.

![Layer B Buttons Top](/articles/assets/2024-12-16-dirtywave-m8-and-x-touch-mini/layer-b-buttons-top.png)
![Layer B Buttons Bottom](/articles/assets/2024-12-16-dirtywave-m8-and-x-touch-mini/layer-b-buttons-bottom.png)

Both button rows are assigned to start a particular song row. The M8's
screen displays the first 16 song rows and one button is dedicated to each
row. Once a song is longer, this will become impractical, but I'll have to
see that and maybe change that later again.


## Shortcomings and Issues

The X-Touch Mini has a very peculiar setup in the GUI editor, which is a
bit tricky to work with for the M8. The M8 expects for song row cues the
(hexa)decimal number of the row as a `note on`. Usually one would think
that this corresponds to `C-0` for Row 00 or `D-0` for Row 02.

In the GUI of the X-Touch editor you have to pick the first and third entry
from the drop down list to accomplish that. The displayed note values have
some kind of offset baked in them, most probably because some keyboards <88
keys start with `C-2` as their lowest key.

![Strange Numbering](/articles/assets/2024-12-16-dirtywave-m8-and-x-touch-mini/strange-numbering.png)

This affects all note based commands, so song row cues and also mute/solo
notes. You have to count them down from the top of the drop down list until
you get the decimal number, that you need.

A shortcoming, that I don't really like, but that I was unable to work
around is the use of `toggle` vs. `momentary` setting of the buttons for
song row cues. Because if you set the button to `momentary`, the desired
song row starts to play, but since the X-Touch mini then sends a `note off`
as soon as you release the button, the playing stops. But setting them to
`toggle` leaves them lit up, so if you start playing, then change to row 3
and then change then to row 7, the buttons 3 and 7 are both lit up. You can
then deselect 3 without affecting playback, but if you deselect 7, the
playing stops, because that was the last cue the M8 remembered.

If anyone has an idea how to solve that, please let me know
[here](https://github.com/michaelrommel/articles/discussions/1).

Also I did not find any information on how to cue up individual track/rows,
like you can do with the Launchpad Pro surface. Since Tim (understandably)
did not make the source code open, I have no idea, how to find that out...

