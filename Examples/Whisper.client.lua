local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WHISPER_ASSET_ID = 9126214337
local WHISPER_ASSET_NAME = "Whisper"

local RbxSound = require(ReplicatedStorage:WaitForChild("RbxSound"))

RbxSound.Static.newSound(WHISPER_ASSET_NAME, {
		[RbxSound.Key.Properties] = {
			SoundId = WHISPER_ASSET_ID,
			Volume = 0.2
		},
	}, {
		[RbxSound.Effects.PitchShiftSoundEffect] = {
			Octave = 0.5
		}
	}
)

RbxSound.Static.playSFX(WHISPER_ASSET_NAME, {
	[RbxSound.Key.StereoChannel] = RbxSound.Enum.SteroChannelType.RightPersistent
}):andThen(function()
	print("Whisper Complete!")
end)