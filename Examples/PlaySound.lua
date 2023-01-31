local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TEST_SOUND_ASSET_ID = 1848354536
local TEST_ASSET_NAME = "Relaxed_Scene"

local STINGER_ASSET_NAME = "Relaxed_Stinger"
local STINGER_SOUND_ASSET_ID = 9120705982

local GROUP_ASST_NAME = "Global"

local RbxSound = require(ReplicatedStorage:WaitForChild("RbxSound"))

RbxSound.Static.newSoundGroup(GROUP_ASST_NAME, {
	[RbxSound.Effects.PitchShiftSoundEffect] = {
		Octave = 1.25
	}
})

RbxSound.Static.newSound(STINGER_ASSET_NAME, { [RbxSound.Key.Properties] = { SoundId = STINGER_SOUND_ASSET_ID }, [RbxSound.Key.SoundGroup] = GROUP_ASST_NAME }, { })
RbxSound.Static.newSound(TEST_ASSET_NAME, {
		[RbxSound.Key.Properties] = { SoundId = TEST_SOUND_ASSET_ID },
		-- [RbxSound.Key.Stinger] = STINGER_ASSET_NAME,
		[RbxSound.Key.SoundGroup] = GROUP_ASST_NAME,
	}, {
		[RbxSound.Effects.PitchShiftSoundEffect] = {
			Octave = 1.25
		}
	}
)

RbxSound.Static.playSFX(TEST_ASSET_NAME, {
	[RbxSound.Key.StereoChannel] = RbxSound.Enum.SteroChannelType.RightPersistent
}):andThen(function()
	print('Finished Playing Background SFX')
end)

RbxSound.Signal.onBackgroundSoundFinished:Connect(function()
	RbxSound.Static.stopBackgroundSFX(true)
end)