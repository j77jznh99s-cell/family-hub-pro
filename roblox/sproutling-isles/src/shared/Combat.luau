--!strict
-- Combat tuning shared by server (CombatService, EnemyService) and client (combat HUD/input).
-- Cartoon combat: knockback and pops of light, no blood. All numbers live here.

local Combat = {}

Combat.Player = {
	maxHealth = 100,
	maxStamina = 100,
	staminaRegen = 22, -- per second
	staminaRegenDelay = 0.8, -- seconds after spending before regen starts
	dodgeCost = 25,
	dodgeSpeed = 70, -- studs/second burst
	dodgeTime = 0.3, -- invulnerable for this long
	dodgeCooldown = 0.6,
}

export type Weapon = {
	id: string,
	name: string,
	kind: string, -- "melee" | "projectile"
	damage: number,
	cooldown: number,
	stamina: number,
	range: number, -- melee reach, or projectile max distance
	arc: number?, -- melee: half-angle in degrees
	speed: number?, -- projectile studs/second
	radius: number?, -- projectile hit radius
	knockback: number,
	color: Color3?,
}

Combat.Weapons = {
	sword = { id = "sword", name = "Knight's Sword", kind = "melee", damage = 18, cooldown = 0.45, stamina = 8, range = 9, arc = 70, knockback = 28 },
	bow = { id = "bow", name = "Hunter's Bow", kind = "projectile", damage = 14, cooldown = 0.6, stamina = 6, range = 160, speed = 140, radius = 2.5, knockback = 12 },
	staff = { id = "staff", name = "Arcane Staff", kind = "projectile", damage = 22, cooldown = 0.9, stamina = 12, range = 110, speed = 90, radius = 3.5, knockback = 20 },
} :: { [string]: Weapon }
Combat.WeaponOrder = { "sword", "bow", "staff" }

export type Ability = {
	id: string,
	name: string,
	key: string, -- keyboard key name (Enum.KeyCode member)
	cooldown: number,
	stamina: number,
	damage: number?,
	radius: number?,
	heal: number?,
	speed: number?,
	range: number?,
}

Combat.Abilities = {
	{ id = "whirlwind", name = "Whirlwind", key = "Q", cooldown = 6, stamina = 20, damage = 26, radius = 12 },
	{ id = "firebolt", name = "Firebolt", key = "X", cooldown = 4, stamina = 15, damage = 34, radius = 8, speed = 110, range = 140 },
	{ id = "secondwind", name = "Second Wind", key = "C", cooldown = 20, stamina = 0, heal = 35 },
} :: { Ability }

-- Boss attack patterns. "slam": everything within radius of the boss; "swipe": a frontal arc;
-- "roots": a circle that erupts under the target's feet. All are telegraphed on the ground
-- for `windup` seconds first, so they can be dodged or walked out of.
export type BossAttack = {
	kind: string,
	damage: number,
	radius: number,
	windup: number,
	arc: number?, -- swipe half-angle in degrees
}

export type EnemyType = {
	id: string,
	name: string,
	health: number,
	damage: number,
	speed: number,
	attackRange: number,
	attackWindup: number, -- telegraph before the hit lands (dodge window)
	attackCooldown: number,
	aggroRange: number,
	reward: number, -- Dew on kill
	respawn: number, -- seconds
	dummy: boolean?, -- training dummy: no AI, regenerates
	boss: boolean?,
	attacks: { BossAttack }?,
	size: number?, -- model scale for bosses
}

Combat.Enemies = {
	slime = { id = "slime", name = "Bog Slime", health = 40, damage = 8, speed = 10, attackRange = 5, attackWindup = 0.6, attackCooldown = 1.6, aggroRange = 35, reward = 4, respawn = 18 },
	goblin = { id = "goblin", name = "Thornback Goblin", health = 70, damage = 12, speed = 15, attackRange = 6, attackWindup = 0.5, attackCooldown = 1.3, aggroRange = 45, reward = 9, respawn = 25 },
	wolf = { id = "wolf", name = "Ashen Wolf", health = 55, damage = 10, speed = 21, attackRange = 6, attackWindup = 0.35, attackCooldown = 1.1, aggroRange = 55, reward = 7, respawn = 22 },
	skeleton = { id = "skeleton", name = "Crypt Skeleton", health = 60, damage = 11, speed = 13, attackRange = 6, attackWindup = 0.5, attackCooldown = 1.4, aggroRange = 50, reward = 8, respawn = 30 },
	bat = { id = "bat", name = "Gloom Bat", health = 25, damage = 6, speed = 24, attackRange = 5, attackWindup = 0.3, attackCooldown = 1, aggroRange = 60, reward = 3, respawn = 25 },
	-- the mountains and the sky isles (quest areas)
	golem = { id = "golem", name = "Crag Golem", health = 150, damage = 16, speed = 9, attackRange = 7, attackWindup = 0.8, attackCooldown = 2, aggroRange = 40, reward = 14, respawn = 30 },
	wisp = { id = "wisp", name = "Storm Wisp", health = 45, damage = 9, speed = 18, attackRange = 6, attackWindup = 0.4, attackCooldown = 1.2, aggroRange = 50, reward = 8, respawn = 25 },
	stormcaller = {
		id = "stormcaller", name = "Stormcaller, Eye of the Gale", health = 1700, damage = 24, speed = 12, attackRange = 12, attackWindup = 1, attackCooldown = 2.2, aggroRange = 70, reward = 260, respawn = 240,
		boss = true, size = 2.2,
		attacks = {
			{ kind = "slam", damage = 30, radius = 16, windup = 1.2 },
			{ kind = "roots", damage = 22, radius = 9, windup = 1 },
			{ kind = "swipe", damage = 26, radius = 16, windup = 0.8, arc = 75 },
		},
	},
	warden = {
		id = "warden", name = "The Bone Warden", health = 1400, damage = 22, speed = 11, attackRange = 12, attackWindup = 1, attackCooldown = 2.2, aggroRange = 70, reward = 150, respawn = 0,
		boss = true, size = 2.2,
		attacks = {
			{ kind = "swipe", damage = 24, radius = 16, windup = 0.8, arc = 70 },
			{ kind = "slam", damage = 30, radius = 18, windup = 1.3 },
			{ kind = "roots", damage = 20, radius = 9, windup = 1.1 },
		},
	},
	treant = {
		id = "treant", name = "Ironbark, the Old Grove", health = 2000, damage = 26, speed = 9, attackRange = 14, attackWindup = 1, attackCooldown = 2.4, aggroRange = 80, reward = 220, respawn = 300,
		boss = true, size = 2.8,
		attacks = {
			{ kind = "slam", damage = 32, radius = 20, windup = 1.4 },
			{ kind = "roots", damage = 22, radius = 10, windup = 1 },
			{ kind = "swipe", damage = 26, radius = 18, windup = 0.9, arc = 80 },
		},
	},
	dummy = { id = "dummy", name = "Training Dummy", health = 200, damage = 0, speed = 0, attackRange = 0, attackWindup = 0, attackCooldown = 0, aggroRange = 0, reward = 0, respawn = 3, dummy = true },
} :: { [string]: EnemyType }

-- Enemy camps on the hills (x, z; y comes from the terrain) and how many of what spawn there.
Combat.Camps = {
	{ x = -430, z = -100, kind = "goblin", count = 4 },
	{ x = -450, z = 250, kind = "wolf", count = 4 },
	{ x = 470, z = -140, kind = "slime", count = 5 },
	{ x = 480, z = 120, kind = "goblin", count = 4 },
	{ x = 470, z = 450, kind = "wolf", count = 3 },
	{ x = 200, z = -520, kind = "slime", count = 4 },
	{ x = -200, z = -520, kind = "slime", count = 4 },
	-- south of the city walls and out in the wider land
	{ x = -300, z = 1420, kind = "goblin", count = 5 },
	{ x = 330, z = 1420, kind = "wolf", count = 4 },
	{ x = -700, z = 1300, kind = "slime", count = 5 },
	{ x = -880, z = -300, kind = "wolf", count = 4 },
	{ x = 1000, z = 600, kind = "goblin", count = 5 },
	{ x = 720, z = 1180, kind = "wolf", count = 3 },
}

-- Training dummies: the server uses the DummySpot markers in the barracks yard (CityBuilder);
-- these are a fallback for a map without them.
Combat.Dummies = { { x = 150, z = 990 }, { x = 170, z = 990 }, { x = 190, z = 990 }, { x = 210, z = 990 } }

Combat.LeashRange = 90 -- enemies give up and walk home past this distance from their camp

-- The overworld boss's clearing (a flat Landscape site, see Landscape.SiteList "grove").
Combat.FieldBoss = { kind = "treant", site = "grove" }

return Combat
