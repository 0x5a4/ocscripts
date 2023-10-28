# ocscripts
These are programs for the [OpenComputers](https://modrinth.com/mod/opencomputers) mod
I use in my personal attempt to fully automate the crafting of the Infinity Ingot from the [Avaritia](https://www.curseforge.com/minecraft/mc-mods/avaritia) mod.

## DISCLAIMER
I dont expect anyone to have an actual use case for this. This repo mainly serves as a memory for myself.
Documentation is only provided for completeness sake and so that future-me can still understand whats going on.

## Programs
### carp
`carp` can be used to remotely synchronize data and system state of the host system. It can also 
fetch centralized data stored on the "master" server and run user defined hooks. 

### salmon (TODO)
`salmon` can be used as a "master" server, controlling multiple instances of `carp`. 

### autodire
(Requires a robot) Fully automate the Dire Crafting Table. Kill me now.  
NOTE: This can merely extract all required Items from the ME. For the actual autocrafting [Avaritiaaddons](https://www.curseforge.com/minecraft/mc-mods/avaritiaddons) is required.

### witherbegone
(Requires a robot) Autospawn the wither. Requires some sort of Block Placer(e.g. OpenBlocks) and a
way to kill the wither(e.g. Draconic Evolution). Make sure the withers come-to-life explosion
happens some distance away from the robot as it will destroy the robot otherwise. In general
be careful not to blow the whole mechanism up.

