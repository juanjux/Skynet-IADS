do
-- Currenthill's Swedish Military Assets Pack: https://www.currenthill.com/
--
-- Not part of upstream PR walder/Skynet-IADS#113, which covers China, Germany, Russia,
-- the UK and the US. Written here because the Retribution fork fields these systems and
-- a system with no entry is rejected outright: addSAMSite calls goLive() and only then
-- cleanUp(), so the site is left radiating and outside the network -- worse than not
-- being in it.
--
-- Unit type names and the split between radars and launchers are read off the fork's own
-- unit definitions and presets (resources/units/ground_units, resources/groups), not
-- guessed. All of these put their radar and their launchers in one group, which is what
-- Skynet needs: it accepts a site only if the group holds both.

-- LvS-103, the Swedish IRIS-T SLM. PM103 is the surveillance radar (the HX suffix is the
-- same radar on the heavier truck), StriE103 the fire control, Lavett103 the launchers.
-- The Elverk103 generator and the C2 are left out on purpose: 'misc' is documentation,
-- nothing in Skynet reads it. HARM figures are the German IRIS-T SML's -- same missile,
-- same class of radar.
samTypesDB['LvS-103'] = {
	['type'] = 'complex',
	['searchRadar'] = {
		['CH_LvS-103_PM103'] = {
		},
		['CH_LvS-103_PM103_HX'] = {
		},
	},
	['trackingRadar'] = {
		['CH_LvS-103_StriE103'] = {
		},
	},
	['launchers'] = {
		['CH_LvS-103_Lavett103_Rb103A'] = {
		},
		['CH_LvS-103_Lavett103_Rb103B'] = {
		},
		['CH_LvS-103_Lavett103_HX_Rb103A'] = {
		},
		['CH_LvS-103_Lavett103_HX_Rb103B'] = {
		},
	},
	['name']  = {
		['NATO'] = 'LvS-103'
	},
	['harm_detection_chance'] = 79,
	['can_engage_harm'] = true
}

-- RBS 70 and RBS 98 are separate systems that share one radar, the UndE 23. Both are
-- fielded by the fork as SHORAD, and GroupTask.SHORAD maps to IadsRole.SAM, so both are
-- handed to Skynet as SAM sites and both need an entry.
--
-- The two figures below are the same for each because they belong to the radar, not to
-- the missile, and it is the same radar: 22, the band this pack gives its other modern
-- radar SHORAD (Skynex SPAAG). Neither can engage a HARM -- the RBS 70 rides a laser
-- beam and the RBS 98 is the IR IRIS-T SLS -- so both say so, as the pack's own IR
-- launchers do.
samTypesDB['RBS 70'] = {
	['type'] = 'complex',
	['searchRadar'] = {
		['CH_UndE23'] = {
		},
	},
	['launchers'] = {
		['CH_RBS-70'] = {
		},
	},
	['name']  = {
		['NATO'] = 'RBS 70'
	},
	['harm_detection_chance'] = 22,
	['can_engage_harm'] = false
}

samTypesDB['RBS 98'] = {
	['type'] = 'complex',
	['searchRadar'] = {
		['CH_UndE23'] = {
		},
	},
	['launchers'] = {
		['CH_RBS-98'] = {
		},
	},
	['name']  = {
		['NATO'] = 'RBS 98'
	},
	['harm_detection_chance'] = 22,
	['can_engage_harm'] = false
}

-- The same IRIS-T SLM the German file above already covers, under the older unit names
-- the fork still ships (CHAP_ rather than CH_). Given its own key rather than merged into
-- that entry so the files taken from PR #113 stay untouched and easy to re-sync; the two
-- cannot be confused, since Skynet matches on unit type and no type appears in both. It
-- reports under the same NATO name either way.
samTypesDB['IRIS-T SLM CHAP'] = {
	['type'] = 'complex',
	['searchRadar'] = {
		['CHAP_IRISTSLM_STR'] = {
		},
	},
	['launchers'] = {
		['CHAP_IRISTSLM_LN'] = {
		},
	},
	['name']  = {
		['NATO'] = 'IRIS-T SLM'
	},
	['harm_detection_chance'] = 79,
	['can_engage_harm'] = true
}

end
