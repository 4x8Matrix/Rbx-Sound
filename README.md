# Rbx-Sound
RbxSound: A RBX (Roblox) Sound library which helps to take advantage of roblox sound effects & sound groups.

Version: 1.0.2
Repository: https://github.com/4x8Matrix/Rbx-Sound
Developer: https://github.com/4x8Matrix

---

## Example

```lua
-- Generation of an RBX sound group

RbxSound.newSoundGroup(GROUP_NAME, {
	[RbxSound.Effects.PitchShiftSoundEffect] = {
		Octave = 1.25
	}
})
```

```lua
-- Generation of an RBX sound attached to the above sound group

RbxSound.newSound(TEST_ASSET_NAME, {
		[RbxSound.Key.Properties] = { SoundId = SOUND_ASSET_ID },
		[RbxSound.Key.SoundGroup] = GROUP_NAME,
	}, {
		[RbxSound.Effects.PitchShiftSoundEffect] = {
			Octave = 1.25
		}
	}
)
```

```lua
-- Playing the above sound asset into the players right-ear.

-- NOTE: 'RightPersistent' means that the sound will stay in the players right-ear given movement of the camera.
-- NOTE: 'Right' will fade-out when the player moves their camera, allowing the SFX to be much more interactive.

RbxSound.playSFX(TEST_ASSET_NAME, {
	[RbxSound.Key.StereoChannel] = RbxSound.Enum.SteroChannelType.RightPersistent
}):andThen(function()
	print('Finished Playing Background SFX')
end)
```

---

## Changelog
> 1.0.0 - 1.0.1:
- Development of the RbxSound library & examples
- 'Wally' publishing on behalf of the developer account mentioned above
    
> 1.0.2:
- Added abilitty to play multiple background SFX's. This howevever means you can only play one background SFX of a specific sound, the previous playing version will stop playing & restart.
- Updated library to remove 'Static' name
- Removed useless type declaration for the Library
- Appended a ChangeLog & Updated header note
- Removing LuaU 'strictness' flag
- Updated package name from 'rbxsound' -> 'RbxSound'

> 1.0.3:
- Addition of a README & Updating the Wally Package
