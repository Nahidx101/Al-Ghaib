# Al-Ghaib
Al Ghaib (“the unseen”) is a 2D side-view platformer built in Godot for NASA Space Apps. In a distant future, a pilgrimage crew visits TRAPPIST-1 f and a disease begins to change them. Only the marines Zayd and Nafis are untouched, and they have about a month to find a cure before the crew is fully taken over.

## Story

In a distant future, a pilgrimage crew visits TRAPPIST-1 f and a disease begins to change them. Only the marines Zayd and Nafis are untouched, and they have about a month to find a cure before the crew is fully taken over.

In Mission 1 you play Zayd. You descend into a pitch-dark cave with only a headlamp and collect a *Bacillus subtilis* specimen. Your tablet barely works underground, so messages from Nafis arrive corrupted. Decrypting one means fixing a flipped bit in a parity grid. The message warns you about a pit ahead.

The tablet is a risk. While you look at it, Zayd is frozen and can't aim his light, and an invisible cold presence closes in. With the tablet shut, it keeps its distance and flees from your beam. You never see it, only frost creeping across the screen, your breath, and a flicker where the light touches it. Oxygen only drains, so grab the sample and get back to the pod.

## Status

Mission 1 is almost playable. Cave design is still remaining.

## Controls

| Key | Action |
|---|---|
| A / D or Left / Right | Move |
| Space or Shift | Jump (hold for a full jump) |
| Mouse | Aim the headlamp |
| Hold E | Collect a sample |
| E (at the pod) | Board the pod |
| Tab | Open / close the tablet |
| R | Restart during play |
| Enter | Restart after game over |

At a signal spot, Tab opens the message puzzle. Anywhere else, it shows the planetary survey.

## How to play

1. Walk into the cave and find the signal spot. Press Tab and fix the one flipped bit: the row and column whose counts are wrong cross at the damaged cell.
2. Collect the sample at the deepest point.
3. Return to the pod before your oxygen runs out, and press E.

## Run it

1. Install Godot 4.x (built with 4.7.2, Compatibility renderer).
2. Open `project.godot` in Godot.
3. Press F5.

## Real NASA data

- **NASA Exoplanet Archive** (Planetary Systems table): TRAPPIST-1 f values shown on the in-game tablet (orbital period, semi-major axis, radius, mass, eccentricity, equilibrium temperature, host star, distance). https://exoplanetarchive.ipac.caltech.edu/cgi-bin/TblView/nph-tblView?app=ExoTbls&config=PSCompPars
- **NASA Open Science Data Repository**: study OSD-185 (BRIC-21, *Bacillus subtilis*, ISS), used for the sample. https://osdr.nasa.gov/bio/repo/data/studies/OSD-185

The message grid is inspired by the 1974 Arecibo message (Cornell University / NSF, not NASA) and by the parity and error correction used in space communication.

## Credits

- **Team:** baybarz
- **Engine:** Godot [version]
- **Pod, sample and signal beacon art:** generated with gemini, then edited by the team
- **Portraits:** comic-style portraits made from photos of team members, used with their permission

## License
Code: MIT License (see LICENSE). Third-party assets keep their own licenses, listed in Credits.
