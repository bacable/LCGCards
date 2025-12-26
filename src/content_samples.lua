local love = require "love"

local ContentSamples = {}

local function makeGenericPlayerCard(gameId, n)
    local name = (gameId == "marvel_champions" and ("Demo Event " .. n))
        or (gameId == "lotr_lcg" and ("Demo Event " .. n))
        or (gameId == "arkham_lcg" and ("Demo Event " .. n))
        or (gameId == "ashes_reborn" and ("Demo Action Spell " .. n))
        or ("Demo Card " .. n)

    local subType = (gameId == "arkham_lcg") and "event" or ((gameId == "ashes_reborn") and "spell_action" or nil)

    return {
        id=("DEMO_DRAW_"..gameId.."_"..n),
        game=gameId,
        sides = {
            front = {
                name=name,
                cardType="event",
                cardSubType=subType,
                role="player",
                stats={},
                text="Drawn from deck.\nPress D to discard selected.\nPress E to exhaust.",
            }
        },
        defaultSideId="front",
        printings={ { setId="DEMO", setName="Demo", cardNumbers={ 300 + n }, modularTags={"Demo"} } }
    }
end

local function sampleDefs_Marvel()
    local heroDef = {
        id="MC_DEMO_IDENTITY", game="marvel_champions",
        sides = {
            alter_ego = {
                name="Demo Alter-Ego",
                cardType="identity", cardSubType="alter_ego", role="player",
                handSize=6,
                stats={ recover=3, hitPoints=11 },
                traits={ "Civilian" },
                text="Alter-ego ability (paraphrased).\nRight-click to flip to Hero.\nPress E to exhaust/ready.",
                canFlipTo={ "hero" },
            },
            hero = {
                name="Demo Hero",
                cardType="identity", cardSubType="hero", role="player",
                handSize=5,
                stats={ thwart=2, attack=2, defense=2, hitPoints=11 },
                traits={ "Avenger" },
                text="Hero ability (paraphrased).\nRight-click to flip to Alter-Ego.\nPress E to exhaust/ready.",
                canFlipTo={ "alter_ego" },
            },
        },
        defaultSideId="alter_ego",
    }

    local villainDef = {
        id="MC_DEMO_VILLAIN", game="marvel_champions",
        sides = {
            stage1 = {
                name="Demo Villain I",
                cardType="scenario", cardSubType="villain", role="encounter",
                stats={ attack=2, scheme=1, hitPoints=14 },
                traits={ "Criminal" },
                text="Stage I.\nRight-click to advance to Stage II.",
                canFlipTo={ "stage2" },
            },
            stage2 = {
                name="Demo Villain II",
                cardType="scenario", cardSubType="villain", role="encounter",
                stats={ attack=3, scheme=2, hitPoints=16 },
                traits={ "Criminal" },
                text="Stage II.\nFinal stage for demo.",
                canFlipTo={},
            },
        },
        defaultSideId="stage1",
    }

    local sideSchemeDef = {
        id="MC_DEMO_SIDE_SCHEME", game="marvel_champions",
        sides = {
            front = {
                name="Demo Side Scheme",
                cardType="treachery", cardSubType="hazard", role="encounter",
                stats={ threat=3 },
                text="Enters with threat.\n(Encounter-side persistent objective.)",
            }
        },
        defaultSideId="front",
    }

    return { heroDef, villainDef, sideSchemeDef }
end

local function sampleDefs_LOTR()
    local heroDef = {
        id="LOTR_DEMO_HERO", game="lotr_lcg",
        sides = {
            front = {
                name="Demo Hero",
                cardType="identity", cardSubType="lotr_hero", role="player",
                stats={ willpower=2, attack=2, defense=1, hitPoints=4 },
                traits={ "Noble" },
                text="Response (paraphrased).\nPress E to exhaust/ready.",
            }
        },
        defaultSideId="front",
    }

    local questDef = {
        id="LOTR_DEMO_QUEST_STAGE1", game="lotr_lcg",
        sides = {
            A = {
                name="Demo Quest 1A",
                cardType="scenario", cardSubType="quest", role="encounter",
                stats={ questPoints=6 },
                text="Setup / When Revealed (paraphrased).\nRight-click to flip to 1B.",
                canFlipTo={ "B" },
            },
            B = {
                name="Demo Quest 1B",
                cardType="scenario", cardSubType="quest", role="encounter",
                stats={ questPoints=6 },
                text="While this stage is active...\n(paraphrased)",
                canFlipTo={},
            },
        },
        defaultSideId="A",
    }

    local locationDef = {
        id="LOTR_DEMO_LOCATION", game="lotr_lcg",
        sides = {
            front = {
                name="Demo Location",
                cardType="location", cardSubType="travel_location", role="encounter",
                stats={ threat=2, questPoints=3 },
                text="Travel: (paraphrased).\nBelongs in staging or active location.",
            }
        },
        defaultSideId="front",
    }

    return { heroDef, questDef, locationDef }
end

local function sampleDefs_Arkham()
    local investigatorDef = {
        id="AH_DEMO_INVESTIGATOR", game="arkham_lcg",
        sides = {
            front = {
                name="Demo Investigator",
                cardType="identity", cardSubType="investigator", role="player",
                stats={ willpower=3, intellect=3, combat=2, agility=2, health=8, sanity=6 },
                traits={ "Detective" },
                text="Ability (paraphrased).\nBack side has deckbuilding.\nRight-click to flip.",
                canFlipTo={ "back" },
            },
            back = {
                name="Demo Investigator",
                cardType="identity", cardSubType="investigator", role="player",
                text="Deckbuilding + story text (paraphrased).\nRight-click to flip front.",
                canFlipTo={ "front" },
            }
        },
        defaultSideId="front",
    }

    local agendaDef = {
        id="AH_DEMO_AGENDA_1", game="arkham_lcg",
        sides = {
            front = {
                name="Agenda 1a",
                cardType="scenario", cardSubType="agenda", role="encounter",
                stats={ doomThreshold=3 },
                text="Doom advances this.\nRight-click to flip to 1b.",
                canFlipTo={ "back" },
            },
            back = {
                name="Agenda 1b",
                cardType="scenario", cardSubType="agenda", role="encounter",
                text="When advanced: do bad things.\n(paraphrased)",
                canFlipTo={},
            }
        },
        defaultSideId="front",
    }

    local locationDef = {
        id="AH_DEMO_LOCATION", game="arkham_lcg",
        sides = {
            unrevealed = {
                name="Demo Location (Unrevealed)",
                cardType="location", cardSubType="investigation_location", role="encounter",
                text="Unrevealed side.\nRight-click to reveal.",
                canFlipTo={ "revealed" },
            },
            revealed = {
                name="Demo Location",
                cardType="location", cardSubType="investigation_location", role="encounter",
                stats={ shroud=2, cluesPerInvestigator=1 },
                text="Revealed side.\nInvestigate here.",
                canFlipTo={ "unrevealed" },
            }
        },
        defaultSideId="unrevealed",
    }

    return { investigatorDef, agendaDef, locationDef }
end

local function sampleDefs_Ashes()
    local phoenixbornDef = {
        id="ASHES_DEMO_PHOENIXBORN", game="ashes_reborn",
        sides = {
            front = {
                name="Demo Phoenixborn",
                cardType="identity", cardSubType="phoenixborn", role="player",
                stats={ life=15, battlefield=5, spellboard=3 },
                traits={ "Natural" },
                text="Phoenixborn powers (paraphrased).\nPress E to exhaust/ready.",
                canFlipTo={ "back" },
            },
            back = {
                name="Demo Phoenixborn",
                cardType="identity", cardSubType="phoenixborn", role="player",
                text="Back side / deckbuilding (paraphrased).",
                canFlipTo={ "front" },
            }
        },
        defaultSideId="front",
    }

    local bossDef = {
        id="ASHES_CORPSE_OF_VIROS_DEMO", game="ashes_reborn",
        sides = {
            front = {
                name="The Corpse of Viros",
                cardType="enemy", cardSubType="boss", role="encounter",
                stats={ health=30, threat=6, ultimate=5 },
                traits={ "Chimera" },
                text=
                    "Chimera (Boss)\n" ..
                    "Difficulty: Heroic Level 1\n" ..
                    "Players: 1–2\n" ..
                    "Starting Pattern stored in redRains.startingPattern.\n" ..
                    "(No stage flipping.)",
                redRains = {
                    difficultyId    = "heroic_1",
                    difficultyLabel = "Heroic Level 1",
                    playersSupported = { 1, 2 },
                    variants = {
                        ["1p"] = { health = 26 },
                        ["2p"] = { health = 30 },
                    },
                    threat   = 6,
                    ultimate = 5,
                    startingPattern = { 1,2,1,1,2,1 },
                },
            },
        },
        defaultSideId="front",
    }

    local readySpellDef = {
        id="ASHES_DEMO_READY_SPELL", game="ashes_reborn",
        sides = {
            front = {
                name="Demo Ready Spell",
                cardType="upgrade", cardSubType="ready_spell", role="player",
                stats={},
                text="Place on spellboard.\nSummon conjurations (paraphrased).",
            }
        },
        defaultSideId="front",
    }

    return { phoenixbornDef, bossDef, readySpellDef }
end

function ContentSamples.deckGameKey(gameId)
    return (gameId == "marvel" and "marvel_champions")
        or (gameId == "lotr" and "lotr_lcg")
        or (gameId == "arkham" and "arkham_lcg")
        or (gameId == "ashes" and "ashes_reborn")
        or gameId
end

function ContentSamples.makeGenericPlayerCard(gameId, n)
    return makeGenericPlayerCard(gameId, n)
end

function ContentSamples.sampleDefs(gameId)
    if gameId == "marvel" then return sampleDefs_Marvel()
    elseif gameId == "lotr" then return sampleDefs_LOTR()
    elseif gameId == "arkham" then return sampleDefs_Arkham()
    elseif gameId == "ashes" then return sampleDefs_Ashes()
    end
    return {}
end

return ContentSamples
