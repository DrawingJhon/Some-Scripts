local Players = game:GetService("Players")

local tool = Instance.new("Tool")
tool.Name = "Grab Head"
tool.RequiresHandle = false
tool.CanBeDropped = false

local function weldFromMotor6D(motor6D)
	local weld = Instance.new("Weld")
	weld.Part0 = motor6D.Part0
	weld.Part1 = motor6D.Part1
	weld.C0 = motor6D.C0
	weld.C1 = motor6D.C1
	return weld
end

local character = owner.Character
local root = character.HumanoidRootPart
local torso = character.Torso
local rShoulder = torso["Right Shoulder"]
local lShoulder = torso["Left Shoulder"]

local rightArm, leftArm

local connectedHead = nil

local function findNearestCharacter(range)
	local nearestMagnitude = range or math.huge

	local target

	for _, char in pairs(workspace:GetChildren()) do
		local otherHead = char:FindFirstChild("Head")
		if not otherHead or char == character then continue end

		local magnitude = (root.Position - otherHead.Position).magnitude

		if magnitude < nearestMagnitude then
			target = char
		end
	end

	return target
end

local function disconnect()
	if not connectedHead then return end
	rightArm:Destroy()
	leftArm:Destroy()
	connectedHead:BreakJoints()
	local tck = connectedHead:GetAttribute("Tick")
	local p = Players:GetPlayerFromCharacter(connectedHead.Parent)
	if p then
		local t_head = connectedHead
		task.delay(3, function()
			if t_head:GetAttribute("Tick") == tck then
				t_head:SetNetworkOwner(p)
			end
		end)
	end
	connectedHead = nil
end

local function connect(target)
	if connectedHead then return end
	NLS([==[
	local owner = game:GetService("Players").LocalPlayer
	local char = owner.Character
	local humanoid = char.Humanoid
	local torso = char.Torso

	char.Animate.Disabled = true

	for _, track in pairs(humanoid:GetPlayingAnimationTracks()) do
		track:Stop()
	end

	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	torso.AssemblyAngularVelocity = torso.CFrame:VectorToWorldSpace(Vector3.new(10, 0, 0))

	workspace.CurrentCamera.CameraSubject = char.Head
	]==], target)

	local t_head = target.Head
	local t_humanoid = target.Humanoid
	local t_torso = target.Torso

	for _, track in pairs(t_humanoid:GetPlayingAnimationTracks()) do
		track:Stop()
	end

	if target:FindFirstChild("Animate") and target.Animate:IsA("Script") then
		target.Animate.Disabled = true
	end

	t_humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	t_torso.AssemblyAngularVelocity = t_torso.CFrame:VectorToWorldSpace(Vector3.new(10, 0, 0))
	t_humanoid.WalkSpeed = 0

	t_humanoid.RequiresNeck = false
	t_head:BreakJoints()
	t_head.Massless = true
	t_head:SetNetworkOwner(owner)

	local weld = Instance.new("Weld")
	weld.Part0 = torso
	weld.Part1 = t_head
	weld.C0 = CFrame.new(0, 1.2, -2.2) * CFrame.Angles(0, math.rad(180), 0)
	weld.Parent = t_head

	rightArm = weldFromMotor6D(rShoulder)
	leftArm = weldFromMotor6D(lShoulder)

	rightArm.Parent = torso
	leftArm.Parent = torso

	rightArm.C0 *= CFrame.new(0.5, 0, 0) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(math.rad(20), 0, 0)
	leftArm.C0 *= CFrame.new(-0.5, 0, 0) * CFrame.Angles(0, 0, math.rad(-90)) * CFrame.Angles(math.rad(20), 0, 0)

	t_head:SetAttribute("Tick", tick())

	local tck = t_head:GetAttribute("Tick")
	t_head.AncestryChanged:Once(function()
		if tck == t_head:GetAttribute("Tick") then
			disconnect()
		end
	end)
	t_head.CanCollide = true
	
	connectedHead = t_head
end

tool.Activated:Connect(function()
	if not connectedHead then
		local target = findNearestCharacter(10)
		if target then
			connect(target)
		end
	else
		disconnect()
	end
end)

tool.Parent = owner.Backpack
