# automatic-rigging
A simple script for automatically rigging 2D skeletons in the Godot game engine. The script takes an existing folder of images and Skeleton, and it adds individual polygons of sprites and physics colliders. It also can create skeleton modifiers automatically.

![Dinosaur example Skeleton2D](https://github.com/0xcafeb33f/automatic-rigging/blob/5a70976c1799f2b040875ca54b32e5038d31a8fe/example_dino.gif)

## Quick tutorial
This isn't a proper addon, though you're welcome to convert it into one with either a fork or PR -- code is CC0 licensed. Therefore, the procedure for using the script is a bit different than typical addons.

1. Create your art. Generally, each bone should be on a separate layer (though, limbs with multiple bones can be together -- this script can make polygons with deformation). Export each layer as a separate PNG (or other image format) in a separate folder. Make sure each image has the same width and height, and don't add any additional offset to each layer. If you were to recombine the layers as-is, they should form the original character in their base state. Also, save an image of the entire character in their base state outside of this folder.
2. Create your basic scene. Create a sub-node under the parent that you will place both the `Sprite2D` and `Skeleton2D` in. Add in a `Sprite2D` of your overall character in their base state, and make a `Skeleton2D` with a number of `Bone2D`s representing each of the sections of your character. Make sure the name of each `Bone2D` corresponds to the name of the image in the folder. Note that non-alphabetic characters are stripped from the name before processing. If you have multiple bones represented by a single image, append a number at the end, e.g. for `LeftArm.png`, name your `Bone2D`s `LeftArm1`, `LeftArm2`, `LeftArm3`, etc.
3. Set up the constants in `rig.gd`. Set `sprite_path` to the folder where you have exported your art within your project, and set `sprite_extension` to the extension of the file format you used. You can leave `polygon_name`, `physics_name`, and `target_name` as-is, or change them to your heart's content -- they are simply the names of the parent nodes to be generated. If you want the script to generate a `SkeletonModification2D`, leave `update_modifications` set to `true`. The tuning factors `alpha_threshold`, `edge_distance`, and `joint_angle` can be modified if you're getting bad results.
4. Open up the scene you have set up. Go to the scripts tab, and right-click on `rig.gd` and click Run.
5. Note, the script has not automatically saved its generated nodes. Test the results. If you like it, press `CTRL+S` to save them. Otherwise, close the scene and reopen it, which will reset it to the status before `rig.gd` was run.
6. Create animations with `AnimationPlayer` that modify the `Target`'s child nodes' locations to move the character around. You can also move the base offset node to move the entire character. Some of the `SkeletonModification2D`s or `Polygon2D`s may need to be tweaked for optimal results.

There is an example scene showing how to use this script in the `example` folder.
