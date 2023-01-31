--!strict

--[[


]]--

-- // SERVICES
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- // CONSTANTS
local DEFAULT_SOUND_GROUP_VOLUME = 0.5
local DEFAILT_SOUND_LOADING_LIFETIME = 5
local DEFAULT_INSTANCE_NAME = "SoundReferenceInstance"

local SOUND_STEREO_OFFSETS = 5

local INTERNAL_SOUND_PROPERTIES_KEY = 1
local INTERNAL_SOUND_EFFECTS_KEY = 2
local INTERNAL_SOUND_PRELOAD_SUCCESS = 3

local INTERNAL_GROUP_EFFECTS_KEY = 1
local INTERNAL_GROUP_INSTANCE_KEY = 2

local EFFECT_SFX_PREFIX = "Effect [%s]"
local BACKGROUND_SFX_PREFIX = "BackgroundSFX [%s]"
local SFX_PREFIX = "SFX [%s]"

-- // IMPORTS
local Signal = require(script.Packages.Signal)
local Promise = require(script.Packages.promise)
local Sift = require(script.Packages.sift)

-- // GENERIC TYPES
export type dictionary<k, v> = { [k]: v }
export type array<v> = dictionary<number, v>

-- // ADVANCED TYPES
export type SoundEffectMap = dictionary<string, any>
export type PromiseObject = typeof(Promise.promisify(function() end))

-- // CLASS
local RbxSoundClass = { }

RbxSoundClass.Interface = { }
RbxSoundClass.Internal = { }
RbxSoundClass.Validators = { }
RbxSoundClass.InstanceReferences = { }
RbxSoundClass.BackgroundAudio = nil

RbxSoundClass.InstanceReferences.Effects = { }
RbxSoundClass.InstanceReferences.Sounds = { }
RbxSoundClass.InstanceReferences.Groups = { }

RbxSoundClass.Interface.Signal = { }
RbxSoundClass.Interface.Key = { }
RbxSoundClass.Interface.Enum = { }
RbxSoundClass.Interface.Static = { }
RbxSoundClass.Interface.Effects = { }

-- // CLASS UNIQUE REFS
RbxSoundClass.Interface.Key.SoundGroup = newproxy()
RbxSoundClass.Interface.Key.WorldPosition = newproxy()
RbxSoundClass.Interface.Key.StereoChannel = newproxy()
RbxSoundClass.Interface.Key.Properties = newproxy()
RbxSoundClass.Interface.Key.Stinger = newproxy()
RbxSoundClass.Interface.Key.FadeOutDuration = newproxy()

-- // CLASS ENUMERATION
RbxSoundClass.Interface.Enum.SteroChannelType = {
	["Left"] = newproxy(), ["LeftPersistent"] = newproxy(),
	["Right"] = newproxy(), ["RightPersistent"] = newproxy()
}

-- // CLASS Signal
RbxSoundClass.Interface.Signal.onSoundPlayed = Signal.new()
RbxSoundClass.Interface.Signal.onSoundStopped = Signal.new()
RbxSoundClass.Interface.Signal.onBackgroundSoundChanged = Signal.new()
RbxSoundClass.Interface.Signal.onBackgroundSoundFinished = Signal.new()

RbxSoundClass.Interface.Signal.onSoundFailedPreload = Signal.new()
RbxSoundClass.Interface.Signal.onSoundSuccessPreload = Signal.new()

RbxSoundClass.Interface.Signal.onSoundInstantiated = Signal.new()
RbxSoundClass.Interface.Signal.onSoundGroupInstantiated = Signal.new()

-- // VARIABLES
local stereoChannelOutputOffsets = {
	[RbxSoundClass.Interface.Enum.SteroChannelType.Left] = CFrame.new(-SOUND_STEREO_OFFSETS, 0, 0),
	[RbxSoundClass.Interface.Enum.SteroChannelType.Right] = CFrame.new(SOUND_STEREO_OFFSETS, 0, 0),
	[RbxSoundClass.Interface.Enum.SteroChannelType.LeftPersistent] = CFrame.new(-SOUND_STEREO_OFFSETS, 0, 0),
	[RbxSoundClass.Interface.Enum.SteroChannelType.RightPersistent] = CFrame.new(SOUND_STEREO_OFFSETS, 0, 0)
}

local persistentStereoChannels = { 
	[RbxSoundClass.Interface.Enum.SteroChannelType.LeftPersistent] = true,
	[RbxSoundClass.Interface.Enum.SteroChannelType.RightPersistent] = true
}

-- // PRIVATE METHODS
function RbxSoundClass.Internal.preloadSoundIds(soundName: string, ...: string)
	local soundIds = { ... }

	return Promise.promisify(function()
		local status

		ContentProvider:PreloadAsync(soundIds, function(assetId, assetFetchStatus)
			if assetFetchStatus == Enum.AssetFetchStatus.Failure then
				RbxSoundClass.Interface.Signal.onSoundFailedPreload:Fire(soundName, assetId)
			else
				RbxSoundClass.Interface.Signal.onSoundSuccessPreload:Fire(soundName, assetId)
			end

			status = assetFetchStatus
		end)

		while not status do
			task.wait()
		end

		return status == Enum.AssetFetchStatus.Success
	end)()
end

function RbxSoundClass.Internal.generateSoundIdFromNumerical(soundId: number)
	return string.format("rbxassetid://%d", (soundId or 0))
end

function RbxSoundClass.Internal.generateSoundIdFromString(soundId: string)
	return RbxSoundClass.Internal.generateSoundIdFromNumerical(string.match(soundId, "%d+"))
end

function RbxSoundClass.Internal.parsePropertiesSoundId(soundName: string, soundProperties: array<any>)
	local soundIdType = typeof(soundProperties[RbxSoundClass.Interface.Key.Properties].SoundId)

	if soundIdType == "string" then
		soundProperties[RbxSoundClass.Interface.Key.Properties].SoundId = RbxSoundClass.Internal.generateSoundIdFromString(soundProperties[RbxSoundClass.Interface.Key.Properties].SoundId)
	elseif soundIdType == "number" then
		soundProperties[RbxSoundClass.Interface.Key.Properties].SoundId = RbxSoundClass.Internal.generateSoundIdFromNumerical(soundProperties[RbxSoundClass.Interface.Key.Properties].SoundId)
	else
		return error(string.format("Expected Sound Name '%s' 'SoundId' to be of ['number', 'string'] type", soundName))
	end
end

function RbxSoundClass.Internal.parsePropertiesStinger(soundProperties: array<any>)
	local stingerName = soundProperties[RbxSoundClass.Interface.Key.Stinger]

	if not soundProperties[RbxSoundClass.Interface.Key.Stinger] or stingerName == "" then
		return
	end

	assert(RbxSoundClass.InstanceReferences.Sounds[stingerName] ~= nil, "Expected 'Stinger' to have a valid sound name")
end

function RbxSoundClass.Internal.setProperties(instance: Instance, properties: dictionary<string, any>)
	for property, value in properties do
		instance[property] = value
	end
end

function RbxSoundClass.Internal.setSoundKeyProperties(soundInstance: Sound, soundProperties: array<any>)
	for key, value in soundProperties do
		if key == RbxSoundClass.Interface.Key.Properties then
			assert(typeof(value) == "table", "Expected 'Properties' table to be a table!")

			RbxSoundClass.Internal.setProperties(soundInstance, value)
		elseif key == RbxSoundClass.Interface.Key.SoundGroup then
			local targetSoundGroup = RbxSoundClass.InstanceReferences.Groups[value]

			assert(typeof(value) == "string", "Expected 'SoundGroup' reference to be a string!")
			assert(targetSoundGroup ~= nil, "Expected 'SoundGroup' reference to exist!")

			soundInstance.SoundGroup = targetSoundGroup[INTERNAL_GROUP_INSTANCE_KEY]
		end
	end
end

function RbxSoundClass.Internal.instantiateEffects(parent: Instance, effectDictionary: SoundEffectMap)
	local effectInstances = { }

	for classNameKey, classProperties in effectDictionary do
		local className = RbxSoundClass.InstanceReferences.Effects[classNameKey]
		local classEffect = Instance.new(className)

		RbxSoundClass.Internal.setProperties(classEffect, classProperties)

		classEffect.Parent = parent
		classEffect.Name = string.format(EFFECT_SFX_PREFIX, className)

		table.insert(effectInstances, classEffect)
	end

	return effectInstances
end

--[[
	Validates developer parameter input for sound properties
]]--
function RbxSoundClass.Validators.validateSoundProperties(soundProperties: array<any>)
	if not soundProperties then
		return { }
	end

	return soundProperties
end

--[[
	Validates developer parameter input for sound effects
]]--
function RbxSoundClass.Validators.validateSoundEffects(soundEffects: dictionary<string, SoundEffectMap>)
	if not soundEffects then
		return { }
	end

	for effectName in soundEffects do
		assert(RbxSoundClass.InstanceReferences.Effects[effectName] ~= nil, string.format("Expected 'RbxSound.Effect.*', was given '%s'", tostring(effectName)))
	end

	return soundEffects
end

-- // PUBLIC METHODS

--[[
	the 'newSound' method instantiates a new sound, before playing any sounds you first need to instantiate them using this method.

	```lua
		RbxSound.newSound("SoundName", {
			[RbxSound.Key.SoundGroup] = "SoundGroupName",
			[RbxSound.Key.Properties] = {
				SoundId = 0,
				Volume = 1
			}
		}, {
			[RbxSound.Effects.PitchShiftSoundEffect] = {
				Octave = 1.25,
				Priority = 0
			}
		})
	```
]]--
function RbxSoundClass.Interface.Static.newSound(soundName: string, soundProperties: array<any>?, soundEffects: dictionary<string, SoundEffectMap>?): typeof(RbxSoundClass.Interface)
	assert(RbxSoundClass.InstanceReferences.Sounds[soundName] == nil, string.format("Sound Name '%s' already exists, failed to instantiate new sound name!", soundName))

	local _, soundPreloadedSuccessfully

	if soundProperties[RbxSoundClass.Interface.Key.Properties] and soundProperties[RbxSoundClass.Interface.Key.Properties].SoundId then
		RbxSoundClass.Internal.parsePropertiesSoundId(soundName, soundProperties)
		RbxSoundClass.Internal.parsePropertiesStinger(soundProperties)

		_, soundPreloadedSuccessfully = RbxSoundClass.Internal.preloadSoundIds(soundName,
			soundProperties[RbxSoundClass.Interface.Key.Properties].SoundId
		):await()
	else
		return error(string.format("Sound Name '%s' 'SoundId' property to exist, 'SoundId' doesn't exist!", soundName))
	end

	RbxSoundClass.InstanceReferences.Sounds[soundName] = {
		[INTERNAL_SOUND_PROPERTIES_KEY] = RbxSoundClass.Validators.validateSoundProperties(soundProperties),
		[INTERNAL_SOUND_EFFECTS_KEY] = RbxSoundClass.Validators.validateSoundEffects(soundEffects),
		[INTERNAL_SOUND_PRELOAD_SUCCESS] = soundPreloadedSuccessfully
	}

	RbxSoundClass.Interface.Signal.onSoundInstantiated:Fire(soundName)

	return RbxSoundClass.Interface
end

--[[
	the 'newSoundGroup' method instantiates a sound group, sound groups are collections of sound instances which have the ability to effect a global audience of sounds.

	```lua
		RbxSound.Static.newSoundGroup("SoundGroupName", {
			[RbxSound.Effects.PitchShiftSoundEffect] = {
				Octave = 1.25,
				Priority = 0
			}
		})
	```
]]--
function RbxSoundClass.Interface.Static.newSoundGroup(groupName: string, soundEffects: dictionary<string, SoundEffectMap>?): typeof(RbxSoundClass.Interface)
	assert(RbxSoundClass.InstanceReferences.Groups[groupName] == nil, string.format("Sound Name '%s' already exists, failed to instantiate new sound name!", groupName))

	local soundGroupInstance = Instance.new("SoundGroup")

	soundEffects = RbxSoundClass.Validators.validateSoundEffects(soundEffects)

	soundGroupInstance.Name = groupName
	soundGroupInstance.Parent = SoundService
	soundGroupInstance.Volume = DEFAULT_SOUND_GROUP_VOLUME

	RbxSoundClass.InstanceReferences.Groups[groupName] = {
		[INTERNAL_GROUP_EFFECTS_KEY] = soundEffects,
		[INTERNAL_GROUP_INSTANCE_KEY] = soundGroupInstance
	}

	RbxSoundClass.Internal.instantiateEffects(soundGroupInstance, soundEffects)
	RbxSoundClass.Interface.Signal.onSoundGroupInstantiated:Fire(groupName)

	return RbxSoundClass.Interface
end

--[[
	the 'playSFX' method plays a sound instance, the 'Properties' help to define a dynamic range of settings for set sound.

	```lua
		RbxSound.Static.playSFX("SoundName", {
			[RbxSound.Key.WorldPosition] = Vector3.new(0, 5, 0),
			[RbxSound.Key.StereoChannel] = RbxSound.Enum.StereoChannelType.Left
		})
	```
]]--
function RbxSoundClass.Interface.Static.playSFX(soundName: string, customSoundProperties: array<any>?): PromiseObject
	return Promise.promisify(function()
		assert(RbxSoundClass.InstanceReferences.Sounds[soundName] ~= nil, string.format("Sound Name '%s' doesn't exist! Failed to play the sound!", soundName))

		local yieldedDeltaTime = 0

		local soundReferenceInstance, soundReferenceSteppedConnection
		local soundInstanceData = RbxSoundClass.InstanceReferences.Sounds[soundName]
		local soundInstance = Instance.new("Sound")

		local soundProperties = RbxSoundClass.Validators.validateSoundProperties(
			Sift.Dictionary.mergeDeep(customSoundProperties, soundInstanceData[INTERNAL_SOUND_PROPERTIES_KEY])
		)

		assert(soundProperties[RbxSoundClass.Interface.Key.FadeOutDuration] == nil, "'FadeOutDuration' property is not supported in SFX instances")
		assert(soundProperties[RbxSoundClass.Interface.Key.Stinger] == nil, "'Stinger' property is not supported in SFX instances")

		RbxSoundClass.Internal.setSoundKeyProperties(soundInstance, soundProperties)
		soundInstance.Name = string.format(SFX_PREFIX, soundName)
		soundInstance.Parent = SoundService
		soundInstance.Looped = false

		RbxSoundClass.Internal.instantiateEffects(soundInstance, soundInstanceData[INTERNAL_SOUND_EFFECTS_KEY])

		if soundProperties[RbxSoundClass.Interface.Key.WorldPosition] or soundProperties[RbxSoundClass.Interface.Key.StereoChannel] then
			soundReferenceInstance = Instance.new("Part")

			RbxSoundClass.Internal.setProperties(soundReferenceInstance, {
				["Transparency"] = 1,
				["Size"] = Vector3.zero,
				["CanCollide"] = false,
				["CanQuery"] = false,
				["CanTouch"] = false,
				["Anchored"] = true,
				["Parent"] = workspace,
				["Name"] = DEFAULT_INSTANCE_NAME
			})

			soundInstance.Parent = soundReferenceInstance

		end

		if soundProperties[RbxSoundClass.Interface.Key.WorldPosition] then
			assert(typeof(soundProperties[RbxSoundClass.Interface.Key.WorldPosition]) == "Vector3", "Expected 'WorldPosition' to be a Vector3!")

			soundReferenceInstance.Position = soundProperties[RbxSoundClass.Interface.Key.WorldPosition]
		elseif soundProperties[RbxSoundClass.Interface.Key.StereoChannel] then
			local stereoOffset = stereoChannelOutputOffsets[soundProperties[RbxSoundClass.Interface.Key.StereoChannel]]

			soundReferenceInstance.CFrame = workspace.CurrentCamera.CFrame * stereoOffset
			if persistentStereoChannels[soundProperties[RbxSoundClass.Interface.Key.StereoChannel]] then
				soundReferenceSteppedConnection = RunService.RenderStepped:Connect(function()
					soundReferenceInstance.CFrame = workspace.CurrentCamera.CFrame * stereoOffset
				end)
			end
		end

		if not RbxSoundClass.InstanceReferences.Sounds[soundName][INTERNAL_SOUND_PRELOAD_SUCCESS] then
			warn(string.format("Attempting to play Sound that failed preload test: '%s'", soundName))
		end

		while not soundInstance.IsLoaded do
			yieldedDeltaTime += task.wait()

			if yieldedDeltaTime >= DEFAILT_SOUND_LOADING_LIFETIME then
				warn(string.format("Infinite yield possible on sound instance '%s'", soundName))

				soundInstance.Loaded:Wait()
			end
		end

		if not RbxSoundClass.InstanceReferences.Sounds[soundName][INTERNAL_SOUND_PRELOAD_SUCCESS] then
			RbxSoundClass.InstanceReferences.Sounds[soundName][INTERNAL_SOUND_PRELOAD_SUCCESS] = true
		end

		soundInstance:Play()
		soundInstance.Ended:Wait()
		soundInstance:Destroy()

		if soundReferenceInstance then
			soundReferenceInstance:Destroy()
		end

		if soundReferenceSteppedConnection then
			soundReferenceSteppedConnection:Disconnect()
		end
	end)()
end

--[[
	The 'stopBackgroundSFX' method is self-explanitory, it's the key method used to stop the currently playing background SFX

	```lua
		RbxSound.Static.playBackgroundSFX("SoundName", {
			[RbxSound.Key.Properties] = {
				Volume = 0.5,
			}
		})
	```

	```lua
		RbxSound.Static.stopBackgroundSFX()
	```
]]
function RbxSoundClass.Interface.Static.stopBackgroundSFX(playStinger: boolean?): PromiseObject
	return Promise.promisify(function()
		if not RbxSoundClass.BackgroundAudio then
			return
		end

		local backgroundSoundProperties = RbxSoundClass.BackgroundAudio[2]
		local backgroundSoundInstance = RbxSoundClass.BackgroundAudio[1]

		if backgroundSoundProperties[RbxSoundClass.Interface.Key.FadeOutDuration] then
			local previousVolume = backgroundSoundInstance.Volume
			local fadeTween = TweenService:Create(backgroundSoundInstance, TweenInfo.new(backgroundSoundProperties[RbxSoundClass.Interface.Key.FadeOutDuration]), {
				Volume = 0
			})

			fadeTween:Play()

			if fadeTween.PlaybackState ~= Enum.PlaybackState.Completed then
				fadeTween.Completed:Wait()
			end

			backgroundSoundInstance.Playing = false
			backgroundSoundInstance.Volume = previousVolume
		end

		if playStinger and backgroundSoundProperties[RbxSoundClass.Interface.Key.Stinger] then
			RbxSoundClass.Interface.Static.playSFX(backgroundSoundProperties[RbxSoundClass.Interface.Key.Stinger])
		end
	end)()
end

--[[
	the 'playBackgroundSFX' method plays a background sound instance, this instance will not respect SteroChannels or the WorldPosition as it's a global sound.

	```lua
		RbxSound.Static.playBackgroundSFX("SoundName", {
			[RbxSound.Key.Properties] = {
				Volume = 0.5,
			}
		})
	```
]]--
function RbxSoundClass.Interface.Static.playBackgroundSFX(soundName: string, customSoundProperties: array<any>?): PromiseObject
	return Promise.promisify(function()
		assert(RbxSoundClass.InstanceReferences.Sounds[soundName] ~= nil, string.format("Sound Name '%s' doesn't exist! Failed to play the sound!", soundName))

		local yieldedDeltaTime = 0
		local yieldedSoundConnection

		local soundInstanceData = RbxSoundClass.InstanceReferences.Sounds[soundName]
		local soundInstance = Instance.new("Sound")

		local soundLoopedIndex = 1

		local soundProperties = RbxSoundClass.Validators.validateSoundProperties(
			Sift.Dictionary.mergeDeep(customSoundProperties, soundInstanceData[INTERNAL_SOUND_PROPERTIES_KEY])
		)

		assert(soundProperties[RbxSoundClass.Interface.Key.StereoChannel] == nil, "'StereoChannel' property is not supported in Background instances")
		assert(soundProperties[RbxSoundClass.Interface.Key.WorldPosition] == nil, "'WorldPosition' property is not supported in Background instances")

		RbxSoundClass.Internal.setSoundKeyProperties(soundInstance, soundProperties)
		soundInstance.Name = string.format(BACKGROUND_SFX_PREFIX, soundName)
		soundInstance.Parent = SoundService
		soundInstance.Looped = true

		RbxSoundClass.Internal.instantiateEffects(soundInstance, soundInstanceData[INTERNAL_SOUND_EFFECTS_KEY])

		while not soundInstance.IsLoaded do
			yieldedDeltaTime += task.wait()

			if yieldedDeltaTime >= DEFAILT_SOUND_LOADING_LIFETIME then
				warn(string.format("Infinite yield possible on sound instance '%s'", soundName))

				soundInstance.Loaded:Wait()
			end
		end

		yieldedSoundConnection = soundInstance.DidLoop:Connect(function()
			soundLoopedIndex += 1

			RbxSoundClass.Interface.Signal.onBackgroundSoundFinished:Fire(soundName, soundLoopedIndex)
		end)

		RbxSoundClass.Interface.Static.stopBackgroundSFX(true)
		RbxSoundClass.BackgroundAudio = { soundInstance, soundProperties }

		soundInstance:Play()
		soundInstance.Ended:Wait()

		yieldedSoundConnection:Disconnect()

		return soundLoopedIndex
	end)()
end

-- // METATABLES
setmetatable(RbxSoundClass.Interface.Effects, {
	__index = function(self, key)
		local value = newproxy()

		RbxSoundClass.InstanceReferences.Effects[value] = key
		rawset(self, key, value)

		return value
	end
})

-- // RETURN
return RbxSoundClass.Interface :: typeof(RbxSoundClass.Interface) & {

}