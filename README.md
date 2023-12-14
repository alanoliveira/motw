# motw (Mod of Training Wolves)

## Description

MOTW is a mod for the game Garou: Mark of the Wolves (Steam version) that adds a enhanced training mode.

## Features

- Record and playback of inputs
- Save and load states
- Input display
- Hitbox display
- Gauge data display

![20231211032316_1](https://github.com/alanoliveira/motw/assets/6012864/a063e380-db0c-48db-b2f8-1f6d2d0d82ff)


## How to use

1. Download the latest **motw.zip** release from the [Releases Page](https://github.com/alanoliveira/motw/releases).
2. Extract the files to any folder on your system.
3. Start **Garou: Mark of the Wolves** and initiate a versus match (Main Menu -> Normal Mode -> Versus).
4. Run `motw.exe`.
5. Press `Start` (pause the game) to access the enhanced training mode menu.
      - Inside the menu press `A` (light punch) to confirm
6. Press `F7` to quit

## How it works

It works by detouring some functions of the original game, and then executing some code 
before and/or after the original function.

This is a scratch of the flow of the game workflow:
```mermaid
graph LR;
classDef event fill:#00f,color:#fff;
IS_FRAME_READY{is frame ready?};
IS_FRAME_READY -->|yes| DRAW_FRAME;
IS_FRAME_READY -->|no| READ_INPUTS;
READ_INPUTS(read inputs):::event --> RUN_OP_CODE;
RUN_OP_CODE(run OP code):::event --> IS_FRAME_COMPLETE;
IS_FRAME_COMPLETE{frame complete?};
IS_FRAME_COMPLETE -->|no| RUN_OP_CODE;
IS_FRAME_COMPLETE -->|yes| PREPARE_FRAME;
PREPARE_FRAME(prepare frame):::event --> DRAW_FRAME;
DRAW_FRAME(draw frame):::event;
```

When this mod run, for each event marked in blue, we detour the original:
```mermaid
%%{init: {  'gitGraph': {'showBranches': true, 'showCommitLabel':true,'mainBranchName': 'GAME'}} }%%
      gitGraph
        commit id:"detour event"
        branch MOD
        commit id:"do stuffs before event"
        commit id:"run original event"
        commit id:"do stuffs after event"
        checkout GAME
        merge MOD id:"event return"

```

Because of the detouring, Windows might think that the game is a virus.  
If you trust, you can add the game to the exceptions of your antivirus.

## Acknowledgments

Everything I learned about how Garou hitboxes work I owe to [dammit](https://dammit.typepad.com/) and his
scripts for [MAME-rr](https://code.google.com/archive/p/mame-rr/).
