---
thumbnailUrl: "/articles/assets/2025-06-10-remote-shell/thumbnail.png"
thumbnailTitle: "Image showing a partially visible shell terminal window"
structuredData: {
    "@context": "https://schema.org",
    "@type": "Article",
    author: {
        "@type": "Person",
        "name": "Michael Rommel",
        "url": "https://michaelrommel.com/info/about",
        "image": "https://avatars.githubusercontent.com/u/919935?s=100&v=4"
    },
    "dateModified": "2025-06-10T21:40:56+02:00",
    "datePublished": "2025-06-10T21:41:01+02:00",
    "headline": "A collaborative shell in your browser",
    "abstract": "Integrating an existing remote shell solution into my site presented a pretty interesting set of challenges to me."
}
tags: ["new", "create", "code", "terminal", "sshx", "shell", "neovim"]
published: true
---

# A collaborative shell in your browser

## Motivation

When I saw the `sshx.io` project of Eric Zhang, I was intrigued. I always wanted to
experiment with a terminal in a browser, embedded into my website. For example to do
a small administrative task on the webserver itself, this would be helpful, especially
since my VPN does not work at work because of their firewall restrictions and deep
packet inspection. And it was written in Rust and Svelte, so that was a bonus.

![Screenshot](/articles/assets/2025-06-10-remote-shell/sshx.jpeg)

The concept of a central small server, that just relays packets between the shell 
and multiple terminal windows, would even allow me to hold connections to two or three
different targets and then choose to which one I need a connection. I would not
be limited to just the webserver itself and hopping from there...

If I would use such a concept, however, I would have liked it integrated into my
own website and under my control and luckily Eric made the software available
under the MIT License. So, credits to him, that was really great and in line
with all of the stuff that I create.


## Analysing and Understanding

To expose shells and terminals to the outside world is always dangerous. I
wanted to understand _exactly_ how it all works and what the attack surface is,
that I would open on my servers and on the clients, that have a shell attached.
I ran the package locally and got the connectivity working out of the box. So I
focused on the networking part and how to move from a dev setup to a production
version. I already had an nginx with SSL termination and LE certificates on my
website, so I took over that config and build up everything locally. Once I had
his original version running with my redis and nginx and had compiled the sshx
client and server versions, I took on the task of integrating the web frontend
into my blog.

I underestimated that.


## Integration & Refactoring

### Svelte 5

My site was already running Svelte 5 and Tailwind 4. So I needed to update the
codebase. And since I do not use Typescript at all, I had to remove all that
type annotation stuff from the code. Maybe I will regret that later, but for now
I am happy and I can easily read and understand the code. The types in Rust are
tough enough.

The pitfall that probably took me the longest to figure out was the changed
event handling in Svelte 5. I made the mistake of focusing on the Svelte 4 -> 5
migration guide instead of reading through the whole event handling description
on the main pages.

Eric's concept used what he calls an 'infinite canvas', an area, which you can
drag around and pinch-zoom and on which the shell windows live. The problem
was, that in Svelte 5 whenever I moved a window, also the canvas moved.
I will call that Canvas "Fabric" from now on, to not confuse that with the HTML
canvas element that the xterm.js folks use for the terminals. 

I could not figure out what was wrong. On paper, everything should have worked.
When I click on a window title, the code called for an `event.stopPropagation()`
and the Fabric should have never seen that click. But it did. Svelte 5 switched
to an event delegation model where basically all components need to use that
same model in order to work and the event handler is residing at the top root
node. Then also `stopPropation()` would have worked. But
the gesture library I used, still hooked up normal `addEventListener`s to the
DOM which then also saw the event, before it reached the root handler.

I reduced the code into a super small demo project to demonstrate the issue.
(You can find the code [here](https://github.com/michaelrommel/drags/). An
older commit on the main branch also has that drags4/5 directories side by side,
if you want to take a peek at the problem. Now the code only shows the corrected
5 version and I modified the code there to have a complete small window
management system in that codebase.)

![Window Mockup](/articles/assets/2025-06-10-remote-shell/drags.png)

With that code I found help on the Svelte discord and issue tracker and the
error on my side was pointed out quickly and I could resolve the problem using
Svelte's `on()` functions. Actions would have also worked.

### Design Choices

During the refactoring I made conscious design decisions, that deviate from
Eric's. I never pan the Fabric using the mouse wheel and Shift keys. I never do
that in Inkscape and other programs, I rather like to pan by dragging the fabric
around. Removing this functionality simplified the code very much and I could
keep most of the default functionality that came with the terminal emulator.

So the current interaction possibilities for a user with write access are:

Mouse:
- clicking on a window's titlebar and moving the mouse drags the window around
- clicking on the lower-right corner and moving the mouse resizes the window
- clicking on the yellow/green titlebar buttons stepwise in-/decreases the
  window size
- clicking on a window's content area and moving the mouse selects text in the
  terminal
- clicking on the Fabric and moving, drags the canvas with all the windows on
  it
- wheel movements on the window's content scrolls the terminal content
- Ctrl-wheel on titlebar or fabric zooms the fabric along with all it's windows

Touch:
- all touch click and drag actions are the same as with a mouse
- the pinch gesture on the fabric zooms the fabric

Also Eric's interface is always fullwindow and all toolbars absolute
positioned and he disabled mobile device's ability to scale. Since I wanted to
embed that into my site, I wanted the navigation to remain there, along with the
legal stuff. That poses a problem, which I often encounter on websites: when I
zoom in on an image and this moves and covers the full screen and I want to zoom
out again, only the image itself zooms and I cannot get back to the control 
elements.

There is to my knowledge no longer a method to reset the device's scale/zoom
from javascript. All previously known methods, e.g. resetting the meta tag
are no longer working. So I implemented a fallback strategy: whenever the user
doubletaps on the fabric, the whole window scrolls to the toolbar on the left
side of the screen, which is always an area, where the native pinch gesture
works.

There is also a resize Observer at work, that makes sure, that the visible
portion of the fabric fills the window's main area without producing scroll
bars. And in case you get lost on that infinite canvas and no longer find your
terminals, there is now a button to collect all windows and re-centers the
fabric at the origin point. The whole UI is fluid and responsive, whether you
change the font size or scale the browswers zoom level or resize the browser
window. All should work fine.


### Separation of Concerns

I tried to separate each window's moving and resizing logic into each
window component and only keep the fabric panning and zooming functionality in
the main component. Eric also used several states for resizing and moving of
windows, in the main session component. That made it harder to understand what
the flow of data from/to the server is and when to reflect changes in the
UI.

![Rubberband](/articles/assets/2025-06-10-remote-shell/rubberband.png)

The way I tried to solve that is by leaving the whole state of a window
completely reactive in svelte. A terminal only communicates it's id up to the
parent component, when it is being moved and that triggers sending the movement
to the server. Scaling of a window is done only in the child component and I now
draw a rubberband around the scaled window with a size indicator and the state
will only be updated once the scaling is finished. I think this choice is better
for a multi-user environment, as scaling and re-rendering a terminal is pretty
taxing and doing that live on many machines is wasteful in my opinion.

Ideally I would have liked to split out the communication handling as well, but
I haven't gotten round to it. Also the code for managing the windows' UI states
is not optimally aligned with the portions of the state that the server keeps.
I have too convoluted methods to synchronize those. I need to either rethink
the data structure that the TermWindow component uses or modify the sshx server.
But I avoided that, in order to keep the rust crates as close to the original as
possible, except the domain name and path changes needed.


### Vector Maths and DOM Mouse Events

Another pain point was the reporting of pointer events by the browser in
relation to the Fabric and the windows. Ideally I would have liked the reports
to be relative to the Fabric element's top left corner. But this was impossible,
as the reports then suddenly jumped to being relative also to the
terminal windows top left corners once the mouse moved over them. So I needed
to go back to window or page offsets and do more complicated maths.

The windows are offset from a center point (the violet dot on the Fabric) and this
center point is offset from the Fabric element's position and subject to the
zoom state of the fabric.

![Canvas](/articles/assets/2025-06-10-remote-shell/canvas.png)

In addition, when you Ctrl-Wheel zoom the fabric or pinch it, your expectation
is, that the point, where you zoom from, stays put and does not move... Also all
the cursors from all the other people need to be spot on, regardless, how their
fabrics are zoomed or panned...


### xterm.js updates

The patch that Eric wrote for the older `xterm.js` version, he used, needed to
be applied to the new version as well. The idea, that he described in the patch
of filtering terminal responses server side is very appealing, as I do not know
which applications may need especially the cursor reports, that for now are
disabled. I guess, when I work with the implementation more, I can see, if that
is important or not.

The current version of 'xterm.js' has a lot of benefits: the selection mechanism
works better and also the glyphs and graphemes are displayed properly, if you
use a nerd font in the terminal. That is my default setting.

Still there are glitches in the implementation and seemingly no one has answers
for that: [CharSizeService measures different heights on various devices](https://github.com/xtermjs/xterm.js/discussions/5347)


## Conclusion

Overall I am very happy with how the integration turned out. It will certainly
be a useful and enjoyable extension to my blog and it was a lot of fun to dive
deeper into the world of window management in a browser. The design blends
seamless into the whole site concept. The feature is behind a login requirement
and in the future, I will probably allow it only for some persons in a role
based auth concept and also shut down the sshx server if not needed.

As always questions or suggestions to this article can be raised
[here](https://github.com/michaelrommel/articles/discussions/).

