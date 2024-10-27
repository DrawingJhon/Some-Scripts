local tool = Instance.new("Tool")
tool.Name = "Kill"
tool.CanBeDropped = false
tool.Grip = CFrame.new(0, 0, 1)

local handle = Instance.new("Part")
handle.Name = "Handle"
handle.Color = Color3.new(1, 0, 0)
handle.Parent = tool

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local character = owner.Character

local remote = Instance.new("RemoteEvent")
remote.Name = "Shoot"

local canShoot = true

remote.OnServerEvent:Connect(function(p, mouseHit, mouseTarget)
	if p ~= owner or not canShoot then return end

	--canShoot = false

	local life_duration = 0.1
	local lifeStart = tick()

	local beam = Instance.new("Part")
	beam.Material = Enum.Material.Neon
	beam.TopSurface = "Smooth"
	beam.BottomSurface = "Smooth"
	beam.Color = Color3.new(1, 0, 0)
	beam.Name = "BEAM"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.Parent = workspace

	--[[beam.Touched:Connect(function(hit)
		local humanoid = hit.Parent:FindFirstChildOfClass("Humanoid")
		if humanoid and not humanoid:IsDescendantOf(owner.Character) then
			humanoid:TakeDamage(50)
		end
	end)]]

	local ball = Instance.new("Part")
	ball.Position = mouseHit.Position
	ball.Anchored = true
	ball.CanCollide = false
	ball.Color = Color3.new(1, 0, 0)
	ball.TopSurface = "Smooth"
	ball.BottomSurface = "Smooth"
	ball.Size = Vector3.new(0.1, 0.1, 0.1)
	ball.Shape = "Ball"
	ball.Transparency = 0.5
	ball.CanQuery = false
	ball.Parent = workspace
	
	local tween = TweenService:Create(ball, TweenInfo.new(0.2), {
		Size = Vector3.new(8, 8, 8)
	})

	tween.Completed:Once(function()
		ball:Destroy()
		tween:Destroy()
	end)

	tween:Play()

	local explosion = Instance.new("Explosion")
	explosion.Position = mouseHit.Position
	explosion.Parent = workspace

	while tick() - lifeStart < life_duration do
		local from = (handle.CFrame * CFrame.new(0, -1, 0)).Position
		local to = mouseHit.Position
		local distance = (from - to).Magnitude
		
		beam.Size = Vector3.new(0.4, 0.4, distance)
		beam.CFrame = CFrame.new(from, to) * CFrame.new(0, 0, -distance / 2) * CFrame.Angles(0, 0, math.rad(tick() * 180))

		RunService.Stepped:Wait()
	end
	
	beam:Destroy()
	
	canShoot = true
end)

remote.Parent = NLS([==[local tool = script.Parent

local remote = script:WaitForChild("Shoot")
local mouse = owner:GetMouse()

tool.Activated:Connect(function()
	remote:FireServer(mouse.Hit, mouse.Target)
end)

]==], tool)

tool.Parent = owner.Backpack
