-- encoding: cyrillic (windows 1251)
script_name("PD Radio")
script_author("donaks")
script_url("github.com/don-aks/PoliceDispatchLua/")
script_version("2.2")
script_version_number(8)
script_properties("work-in-pause")

require "lib.moonloader"
local download_status = require("lib.moonloader").download_status
local inicfg = require "inicfg"
local memory = require "memory"
local json = require ("dkjson")
local encoding = require "encoding"

encoding.default = "CP1251"
local u8 = encoding.UTF8

-- Фикс для 027
package.path = package.path..";"..getWorkingDirectory().."\\?.lua"

require "config.PoliceDispatch.config"

local DISP_IS_SPEAK = false
local VARS_AND_VALUES = {}
local MAP_ICONS = {}
local CFG, INI

local TIME_ENTER_AFK
local IS_CLEAN_QUEUE = false


function chatMessage(text)
	return sampAddChatMessage(u8:decode("[PD Radio v"..thisScript().version.."]: {ffffff}"..text), 0xFF3523)
end

local v = getMoonloaderVersion()
if v < 26 then
	chatMessage("Ваша версия moonloader не поддерживается. Установите 026-beta или выше.")
	chatMessage("Ссылка на скачивание более новой версии: https://www.blast.hk/threads/13305/")
	thisScript():unload()
	return
end

local res, sampev = pcall(require, "lib.samp.events")
if not res then
	chatMessage("Установите SAMP.LUA! {32B4FF}blast.hk/threads/59503{FFFFFF}.")
	thisScript():unload()
	return
end

function main()
	if not isSampLoaded() or not isSampfuncsLoaded() then return end
	while not isSampAvailable() do wait(100) end
	while sampGetCurrentServerName() == "SA-MP" do wait(100) end

	local currentServerName = sampGetCurrentServerName()
	local ip, port = sampGetCurrentServerAddress()
	local currentServerIP = ip..":"..port
	local filesHandle, configFileName = findFirstFile(PATH.config.."servers/*.json")
	for _ = 1, 100000 do
		configFile = io.open(PATH.config.."servers/"..configFileName, "r")
		local config = json.decode(configFile:read("*a"))

		if isValueIsInArray(currentServerIP, toTable(config.serverInfo.ip)) or currentServerName:find(config.serverInfo.name, 1, true) then
			CFG = config
			break
		end
		configFileName = findNextFile(filesHandle)
		if not configFileName then break end
	end
	print(configFileName)
	-- chatMessage("Не удалось считать .json файл! Подробности в moonloader.log.")
	
	-- print("Данного сервера не найдено в конфиге. Завершаю работу скрипта.")
	-- thisScript():unload()
	-- return

	-- Подгрузка .ini
	INI = inicfg.load({
		INI={
			state=true,
			isCheckUpdates=true,
			soundInAFK=false,
			callsVolume=3,
			findVolume=3,
			radioVolume=3,
			userVolume=3,
			radioOnSound="radio_on.wav",
			radioOffSound="radio_on.wav"
		}
	}, PATH.config.."config.ini")

	-- Обновление включений/отключений 
	-- пользовательских эвентов
	local tUser = {}
	if CFG.events.user then
		for i, it in ipairs(CFG.events.user) do
			tUser[i] = true
		end
	end

	local keyServer = CFG.configInfo.name.."_UserEvents"
	if #tUser > 0 then
		if not INI[keyServer] or #tUser ~= #INI[keyServer] then
			INI[keyServer] = tUser
		end
	end

	saveIni()
	if INI.INI.isCheckUpdates then
		local fpath = "%TEMP%/Police Dispath.lua"
		downloadUrlToFile(
			"https://raw.githubusercontent.com/don-aks/PoliceDispatchLua/main/Police%20Dispatch.lua", 
			fpath,
			function(_, status, _, _)
				if status == download_status.STATUS_ENDDOWNLOADDATA then
					if doesFileExist(fpath) then
						local f = io.open(fpath, "r")
						local f_text = f:read("*a")
						f:close()
						local versNum = string.match(f_text, "script_version_number%s*%((%d+)%)")

						if versNum and tonumber(versNum) > thisScript().version_num then
							local versStr = string.match(f_text, "script_version%s*%([\"'](.-)[\"']%)")
							chatMessage("Внимание! Доступно обновление {32B4FF}v"..versStr.."{ffffff}.")
							chatMessage("Для перехода на страницу скрипта используйте меню {32B4FF}/pdradio{ffffff}.")
						end
					end
				end
			end
		)
	end

	sampRegisterChatCommand("pdradio", mainMenu)

	if INI.INI.state then
		chatMessage("Загружен. Управление скриптом: {32B4FF}/pdradio{FFFFFF}. Автор: {32B4FF}vk.com/donaks{FFFFFF}.")
	else
		chatMessage("Отключен! Управление скриптом: {32B4FF}/pdradio{FFFFFF}. Автор: {32B4FF}vk.com/donaks{FFFFFF}.")
	end

	local radioVolume = memory.read(0xBA6798, 1)
	if INI.INI.state and radioVolume == 0 then
		chatMessage("Внимание! Включите радио в настройках для того, чтобы скрипт заработал и перезайдите в игру, если звук не появится.")
	end

	while true do
		wait(20)
		if not INI.INI.soundInAFK then
			if not TIME_ENTER_AFK and isGamePaused() then
				TIME_ENTER_AFK = os.clock()
			elseif TIME_ENTER_AFK and not isGamePaused() then
				TIME_ENTER_AFK = nil
			end
		end

		local btn1 = u8:decode("Выбрать")
		local btn2 = u8:decode("Отмена")
		local result, button, list, _ = sampHasDialogRespond(20000)
		if result and button == 1 then
			listMainMenu = list
			if list == 0 then
				INI.INI.state = not INI.INI.state
				saveIni()
				mainMenu()
			elseif list == 1 then
				INI.INI.isCheckUpdates = not INI.INI.isCheckUpdates
				saveIni()
				mainMenu()
			elseif list == 2 then
				INI.INI.soundInAFK = not INI.INI.soundInAFK
				saveIni()
				mainMenu()
				if not INI.INI.soundInAFK then
					chatMessage("Теперь диспетчер не будет озвучивать события, которые произошли, когда вы были в АФК больше 2х минут.")
				end
			elseif list == 3 then
				sampShowDialog(20001, u8:decode("Громкость {FF4400}вызовов 911:", "Если вы хотите отключить озвучку, введите 0."), 
					btn1, btn2, 1)
			elseif list == 4 then
				sampShowDialog(20001, u8:decode("Громкость {ABCDEF}/find:", "Если вы хотите отключить озвучку, введите 0."), 
					btn1, btn2, 1)
			elseif list == 5 then
				sampShowDialog(20001, u8:decode("Громкость {8D8DFF}/r:", "Если вы хотите отключить озвучку, введите 0."), 
					btn1, btn2, 1)
			elseif list == 6 then
				sampShowDialog(20001, u8:decode("Громкость {66DDAA}user-эвентов:", "Если вы хотите отключить озвучку, введите 0."), 
					btn1, btn2, 1)
			elseif list == 7 then
				mainMenu()
			elseif list == 8 then
				local userEvents = ""
				if INI[CFG.configInfo.name.."_UserEvents"] then
					for i, it in ipairs(INI[CFG.configInfo.name.."_UserEvents"]) do
						userEvents = userEvents .. CFG.events.user[i].name.."\t"..(it and "{21C90E}Вкл." or "{C91A14}Откл.").."\n"
					end
				end
				if userEvents == "" then
					chatMessage("User-эвентов не найдено!")
					mainMenu()
				else
					sampShowDialog(20002, u8:decode("Отключение user-эвентов"), u8:decode(userEvents),
						btn1, btn2, 4)
				end
			elseif list == 9 then
				text = "Введите нужную строку из чата для проверки и воспроизведения:\n"..
				"Для задания цвета строки используйте вначале R: (цвет без #) (Строка)."
				sampShowDialog(20003, u8:decode("Проверка паттерна"), u8:decode(text), btn1, btn2, 1)
			elseif list == 10 then
				IS_CLEAN_QUEUE = true
				wait(100)
				IS_CLEAN_QUEUE = false
				chatMessage("Очередь воспроизведения была очищена.")
			elseif list == 11 then
				mainMenu()
			elseif list == 12 then
				os.execute("start https://github.com/don-aks/PoliceDispatchLua/releases")
			end
		end

		-- Громкость
		local result, button, _, input = sampHasDialogRespond(20001)
		if result and button == 1 then
			if not tonumber(input) or tonumber(input) < 0 then
				chatMessage("Громкость должно быть числом большим или равным нулю.")
			else
				input = tonumber(input)
				if listMainMenu == 2 then INI.INI.callsVolume = input
				elseif listMainMenu == 3 then INI.INI.findVolume = input
				elseif listMainMenu == 4 then INI.INI.radioVolume = input
				elseif listMainMenu == 5 then INI.INI.userVolume = input end
				saveIni()
			end
			mainMenu()
		elseif result then
			mainMenu()
		end

		-- Отключение user эвентов
		local result, button, list, _ = sampHasDialogRespond(20002)
		if result and button == 1 then
			local key = CFG.configInfo.name.."_UserEvents"
			INI[key][list+1] = not INI[key][list+1]
			saveIni()

			local userEvents = ""
			for i, it in ipairs(INI[CFG.configInfo.name.."_UserEvents"]) do
				userEvents = userEvents .. CFG.events.user[i].name.."\t"..(it and "{21C90E}Вкл." or "{C91A14}Откл.").."\n"
			end
			sampShowDialog(20002, u8:decode("Отключение user-эвентов"), u8:decode(userEvents), btn1, btn2, 4)
		elseif result then
			mainMenu()
		end

		-- Проверка строки
		local result, button, _, input = sampHasDialogRespond(20003)
		if result and button == 1 then
			input = input:gsub("^R: (%w+) ", "")
			local color = input:match("^R: (%w+) ")
			if color and not tonumber(color) then
				color = tonumber("0x"..color)
			end

			-- local h, s = handleEvent(input, color)
			sampAddChatMessage(input, (color or -1))
			if h == false and s == "that server message is not triggered event" then
				chatMessage("Событие не найдено. Возможно вы неправильно ввели строку в config.json или в поле для ввода.")
				chatMessage("Либо, если это user-эвент, он может быть отключен в настройках.")
			elseif h == false and s == "volume" then
				chatMessage("Событие, которое вы пытаетесь воспроизвести, отключено.")
			elseif h == false and s == "question words" then
				chatMessage("В сообщении по рации найдено вопросительное слово.")
			elseif h == false and s == "text radio" then
				chatMessage("В сообщении по рации не найдено никаких ключевых слов.")
			elseif h == false and s == "stopWords" then
				chatMessage("В вызове найдены \"стоп-слова\" из config.json.")
			elseif h == false then
				chatMessage("При проверки строки произошла ошибка. Подробнее в moonloader.log.")
			elseif h == true then
				chatMessage("Ваша строка содержала мало данных, поэтому сохранена до следующего события.")
				chatMessage("Примечание: как только придет новая строка в чате, данные обнуляться.")
			else
				chatMessage("Кажется, все прошло успешно.")
			end
		elseif result then
			mainMenu()
		end
	end
end

function sampev.onServerMessage(color, message)
	if not INI or not CFG or not INI.INI.state then return true end
	message = u8(message)

	-- В беск. цикле переменная обновляется позже, чем приходят
	-- сообщения из чата после выхода из АФК.
	if not INI.INI.soundInAFK and TIME_ENTER_AFK and os.clock() - TIME_ENTER_AFK >= 120 then
		return true
	end

	local eventType
	-- По умолчанию user эвенты проверяются самыми первыми.
	if not CFG.user or #CFG.user == 0 then
		return
	end

	for i, ev in ipairs(CFG.events.user) do
		if INI[CFG.name.."_UserEvents"][i] then
			local patterns = toTable(ev.chatMessage)
			local colors = toTable(ev.colorChatMessage)

			if #colors < 1 or (#colors == 1 and colors == color) or isValueIsInArray(tonumber(color), colors) then
				for _, patt in ipairs(patterns) do
					if not ev.useRegexInPattern then
						patt = "^"..(
							patt:gsub("%^", "%%^")
							:gsub("%$", "%%$")
							:gsub("%(", "%%(")
							:gsub("%)", "%%)")
							:gsub("%.", "%%.")
							:gsub("%[", "%%[")
							:gsub("%]", "%%]")
							:gsub("%*", "%%*")
							:gsub("%+", "%%+")
							:gsub("%-", "%%-")
							:gsub("%?", "%%?")
						)
					end

					if message:find(patt:gsub("@([%a_]+)", ".+")) then
						userPattern = patt
						idUserEvent = i
						break
					end
				end
			end
		end
	end


	if userPattern then
		eventType = "user"
	end

	local varsAndValues
	for id_event, ev_type in ipairs(CFG.events) do
		local patterns = toTable(CFG.events[evtype].chatMessage)
		local colors = CFG.events[evtype].colorChatMessage
		
		if #colors < 1 or (#colors == 1 and colors == color) or isValueIsInArray(tonumber(color), colors) then
			for _, patt in ipairs(patterns) do
				if not CFG[evtype].useRegexInPattern then
					patt = "^"..(
						patt:gsub("%^", "%%^")
						:gsub("%$", "%%$")
						:gsub("%(", "%%(")
						:gsub("%)", "%%)")
						:gsub("%.", "%%.")
						:gsub("%[", "%%[")
						:gsub("%]", "%%]")
						:gsub("%*", "%%*")
						:gsub("%+", "%%+")
						:gsub("%-", "%%-")
						:gsub("%?", "%%?")
					)
				end
				
				if str:find(patt:gsub("@([%a_]+)", ".+")) then
					eventType = evtype
					varsAndValues = {}
					local vars = {}

					-- ищем все @var
					local start = 1
					local var
					for _ = 1, #message do
						_, start, var = patt:find("@([%a_]+)", start)
						if var then
							table.insert(vars, var)
						else
							break
						end
					end

					for _, var in ipairs(vars) do
						local patternFindVar = "(.+)"
						if var == "n" or var == "id" then
							patternFindVar = "(%%d+)"
						end

						local patternWithoutVar = patt:gsub(
							"@"..var.."[^%a_]",
							patternFindVar..(patt:match("@"..var.."([^%a_])") or "")
						):gsub("@([%a_]+)", ".+")

						varsAndValues[var] = message:match(patternWithoutVar)

						if not varsAndValues[var] then
							print("Warning: Не найдена переменная @"..var.." в строке \""..message.."\"!")
						end
					end
					
					break
				end
			end
		end
	end

	local markerId = CFG[eventType].markerId
	
	if not eventType then
		-- очищаем, потому что инфа должна быть на следующей строке
		if #VARS_AND_VALUES > 0 then
			VARS_AND_VALUES = {}
		end
		return false, "that server message is not triggered event"
	end

	-- Чекаем остался ли глобальный VARS от предыдущего вызова.
	if VARS[eventType] then
		for k,v in pairs(VARS[event]) do
			varsAndValues[k] = v
		end
		VARS[eventType] = {}
	end

	if eventType == "find" then
		if INI.INI.findVolume == 0 then return false, "volume" end
		-- Если нет обязательного параметра
		if not vars.area then
			if markerId then
				vars.area = getMarkerArea(markerId)
				if not vars.area then
					print("Иконка на карте с id "..markerId.." в эвенте find не найдена.")
					return false
				end
			elseif type(CFG.find.pattern) == "table" and #CFG.find.pattern > 1 then
				-- Оставляем данные на потом
				VARS["find"] = vars
				return true
			else
				print("Ошибка! Перменная @area не указана в эвенте find!")
				print("Укажите markerId или @area в сообщении и перезагрузите скрипт!")
				return false
			end
		end

		vars.vehid = vars.vehid or vars.vehname and getCarModelByName(vars.vehname)

		if CFG.find.vehOnFoot and vars.vehname == CFG.find.vehOnFoot then
			vars.onFoot = true
		elseif vars.nick or vars.id then
			-- Берем инфу об авто исходя из данных игрока
			local playerId = tonumber(vars.id) or sampGetPlayerIdByNickname(vars.nick)
			local playerInStream, playerHandle = sampGetCharHandleBySampPlayerId(playerId)

			if playerInStream and isCharInAnyCar(playerHandle) then
				local carHandle = storeCarCharIsInNoSave(playerHandle)
				vars.vehid = getCarModel(carHandle)
				vars.vehcolor, _ = getCarColours(carHandle)
			end
		end

	elseif eventType == "call" then
		if INI.INI.callsVolume == 0 then return false, "volume" end
		if not vars.area or not vars.text then
			if type(CFG.call.pattern) == "table" and #CFG.call.pattern > 1 then
				VARS["call"] = vars
				return true
			else
				print("Ошибка! Переменная @area или @text не указана в эвенте call!")
				return false
			end
		end

		if isValueIsInArray(vars.text, CFG.config.stopWords) then
			return false, "stopWords"
		end

		if 		CFG.call.isPlayGangActivity and
				isValueIsInArray(str, CFG.config.dictionaryGangActivity) and
				varInElementsArray(vars.area, GANG_ACTIVITY_SOUNDS)
		then
			eventType = "gangActivity"
		elseif 	math.random(2) == 2 and
				varInElementsArray(vars.area, AREA_AND_CODE_SOUNDS) 
		then
			math.randomseed(os.time())
			eventType = "areaAndCode"
		end

	elseif eventType == "radio" then
		if INI.INI.radioVolume == 0 then return false, "volume" end
		if CFG.radio.isPlayShotsFired then
			if isValueIsInArray(vars.text, CFG.config.code0Words) then
				eventType = "code0"
			elseif isValueIsInArray(vars.text, CFG.config.code1Words) then
				eventType = "code1"
			end
		end

		-- Пользовательские эвенты на радио
		if 	eventType == "radio" and
			type(CFG.radio.userMessages) == "table" and
			#CFG.radio.userMessages > 0
		then
			for _, usermsg in ipairs(CFG.radio.userMessages) do
				if isValueIsInArray(vars.text, toTable(usermsg.textFind), usermsg.useRegexInPattern) then
					local sounds = cloneTable(toTable(usermsg.sounds))

					for i, sound in ipairs(sounds) do
						if sound == "@cityplayer" then
							sounds[i] = getAreaSoundPatch(getPlayerCity(PLAYER_PED))
						elseif sound == "@areaplayer" then
							sounds[i] = getAreaSoundPatch(getPlayerArea(PLAYER_PED))
						elseif varname == "@randomtencode" then
							sounds[i] = randomChoice(DISPATCH_SOUNDS.codes)
						elseif varname == "@randomtencodewithin" then
							sounds[i] = randomChoice(DISPATCH_SOUNDS.codesWithIn)
						elseif varname == "@randomarea" then
							sounds[i] = getAreaSoundPatch(randomChoice(AREAS)[1])
						elseif varname == "@randomareaincityplayer" then
							local city = getPlayerCity(PLAYER_PED)
							if not city or city == "San Andreas" then
								-- В принципе рандомный район
								sounds[i] = getAreaSoundPatch(randomChoice(AREAS)[1])
							else
								sounds[i] = getAreaSoundPatch(
									randomChoice(LIST_AREAS_IN_REGIONS[city])
								)
							end
						elseif varname == "@codezero" then
							sound = randomChoice(CODE_0_SOUNDS)
						elseif varname == "@codeone" then
							sound = randomChoice(CODE_1_SOUNDS)
						else
							sounds[i] = PATH.audio..sound:gsub("/", "\\")
						end
					end

					lua_thread.create(
						playSounds,
						sounds,
						"radioVolume",
						usermsg.isPlayRadioOn
					)
					return
				end
			end
			return false, "that server message is not triggered event"
		elseif isValueIsInArray(vars.text, QUESTION_WORDS) then
			return false, "question words"
		elseif ev == "radio" then
			return false, "text radio"
		end

	elseif eventType == "user" then
		if INI.INI.userVolume == 0 then return false, "volume" end
		local arrSounds = {}
		
		local CFGuser = CFG.user[idUserEvent]
		CFGuser.sounds = toTable(CFGuser.sounds)
		for i, sound in ipairs(CFGuser.sounds) do
	
			if type(sound) ~= "string" then
				print("Ошибка в звуке \""..sound.."\" (№"..i..") в user эвенте \""..CFGuser.name.."\"!")
				print("Пользовательские звуки должны быть между кавычками!")
				return false
	
			-- DISP.key1.key2
			elseif sound:find("^DISP%.") then
				local s = sound:split("%.")
				if #s == 2 or #s == 3 then
					local newSound
					if #s == 3 then
						if s[2] == "codes" or s[2] == "codesWithIn" then
							s[3] = tonumber(s[3])
						end
						newSound = DISPATCH_SOUNDS[s[2]][s[3]]
					else
						newSound = DISPATCH_SOUNDS[s[2]]
					end
	
					if not newSound then
						print("Ошибка в звуке \""..sound.."\" (№"..i..") в user эвенте \""..CFGuser.name.."\"!")
						print("Звук не найден! Убедитесь что вы все верно написали.")
						print("Сравните свои ключи с ключами в переменной DISPATCH_SOUNDS в файле config.lua.")
						print("Регистр символов имеет значение!")
						return false
					end
					sound = newSound
				else
					print("Ошибка в звуке \""..sound.."\" (№"..i..") в user эвенте \""..CFGuser.name.."\"!")
					print("Указывать звук нужно: DISP.key1.key2. Пример: DISP.words.headTo10.")
					return false
				end
	
			-- @var
			elseif sound:find("^@") then
				local varname = sound:match("@([%a_]+)")
				if not varname then
					print("Некорректная переменная в звуке "..tostring(sound).." (№"..i..") в user эвенте \""..CFGuser.name.."\"!")
					print("Переменные пишутся только латиницей или нижним подчеркиванием!")
					return false
				end
	
				-- Если переменной нет в строке.
				if 	(not vars[varname]) and 
					(not (CFGuser.vars and CFGuser.vars[varname])) and
					(varname ~= "veh" or not (vars.vehname or vars.vehid))
				then
					if varname == "area" and CFGuser.markerId then
						local markerId = CFGuser.markerId
						local area = getMarkerArea(markerId)
						if not area then
							print("Ошибка в звуке \""..sound.."\" (№"..i..") в user эвенте \""..(CFGuser.name).."\"!")
							print("Иконка на карте с id "..markerId.." в эвенте user не найдена.")
							return false
						end
	
						local newSound = getAreaSoundPatch(area)
						if not newSound then
							print("Ошибка в звуке \""..sound.."\" (№"..i..") в user эвенте \""..CFGuser.name.."\"!")
							print("@area не найдено.")
							return false
						end
						sound = newSound
	
					elseif varname == "veh" then
						if vars.id or vars.nick then
							vars.id = tonumber(vars.id) or sampGetPlayerIdByNickname(vars.nick)
							res, vars.vehid, vars.vehcolor = getModelIdAndColorByPlayerId(vars.id)
							if res then
								for _, soundColor in ipairs(getCarColorSound(vars.vehcolor)) do
									table.insert(arrSounds, soundColor)
								end
								sound = getVehSound(vars.vehid)
							else
								print("Ошибка в звуке \""..sound.."\" (№"..i..") в user эвенте \""..CFGuser.name.."\"!")
								print("Переменной @vehname или @vehid нет в строке!")
								print("И игрок, указанный в переменных @id или @nick вне зоне стрима!")
								return false
							end
						else
							print("Ошибка в звуке \""..sound.."\" (№"..i..") в user эвенте \""..CFGuser.name.."\"!")
							print("Переменной @vehname или @vehid нет в строке!")
							return false
						end
					elseif varname == "suspectveh" then
						-- Копипаст.
						if vars.id or vars.nick then
							vars.id = tonumber(vars.id) or sampGetPlayerIdByNickname(vars.nick)
							res, vars.vehid, vars.vehcolor = getModelIdAndColorByPlayerId(vars.id)
							if res then
								table.insert(arrSounds, DISPATCH_SOUNDS.suspect.suspect1)
								table.insert(arrSounds, DISPATCH_SOUNDS.words.onA)
								for _, soundColor in ipairs(getCarColorSound(vars.vehcolor)) do
									table.insert(arrSounds, soundColor)
								end
								sound = getVehSound(vars.vehid)
							else
								-- ХАХАХАХХАХАХАХАХАХХА
								-- Ладно.
								local playerInStream, playerHandle
	
								local _, playerId = sampGetPlayerIdByCharHandle(PLAYER_PED)
								if id ~= playerId then
									playerInStream, playerHandle = sampGetCharHandleBySampPlayerId(vars.id)
								else
									playerInStream, playerHandle = true, PLAYER_PED
								end
	
								if not playerInStream then
									print("Warning @suspectveh: Игрок вне зоне стрима в user эвенте \""..CFGuser.name.."\"!")
									sound = nil
								else
									table.insert(arrSounds, DISPATCH_SOUNDS.suspect.suspect1)
									sound = DISPATCH_SOUNDS.suspect.onFoot
								end
							end
						else
							print("Ошибка в звуке \""..sound.."\" (№"..i..") в user эвенте \""..CFGuser.name.."\"!")
							print("Переменной @vehname или @vehid нет в строке!")
							return false
						end
					elseif varname == "cityplayer" then
						local city = getPlayerCity(PLAYER_PED)
						if not city then
							local x, y, z = getCharCoordinates(PLAYER_PED)
							print("Ошибка! Не удалось определить город игрока.")
							print("Координаты: x = "..x..", y = "..y..", z = "..z)
							return false
						end
						sound = getAreaSoundPatch(city)
					elseif varname == "areaplayer" then
						local area = getPlayerArea(PLAYER_PED)
						if not area then
							local x, y, z = getCharCoordinates(PLAYER_PED)
							print("Ошибка! Не удалось определить район игрока.")
							print("Координаты: x = "..x..", y = "..y..", z = "..z)
							return false
						end
						sound = getAreaSoundPatch(area)
					elseif varname == "randomtencode" then
						sound = randomChoice(DISPATCH_SOUNDS.codes)
					elseif varname == "randomtencodewithin" then
						sound = randomChoice(DISPATCH_SOUNDS.codesWithIn)
					elseif varname == "randomarea" then
						sound = getAreaSoundPatch(randomChoice(AREAS)[1])
					elseif varname == "randomareaincityplayer" then
						local city = getPlayerCity(PLAYER_PED)
						if not city or city == "San Andreas" then
							-- В принципе рандомный район
							sound = getAreaSoundPatch(randomChoice(AREAS)[1])
						else
							sound = getAreaSoundPatch(
								randomChoice(LIST_AREAS_IN_REGIONS[city])
							)
						end
					elseif varname == "codezero" then
						sound = randomChoice(CODE_0_SOUNDS)
					elseif varname == "codeone" then
						sound = randomChoice(CODE_1_SOUNDS)
					elseif varname == "megaphone" then
						if coords == "player" then
							handleOrId = getPlayerHandleOrIdByVariables(vars)
							setPlay3dAudioStreamAtChar(sound, handleOrId)
						end
						setAudioStreamVolume(sound, 5)
						setAudioStreamState(sound, 1)
					else
						print("Ошибка в звуке \""..sound.."\" (№"..i..") в user эвенте \""..CFGuser.name.."\"!")
						print("Переменной @"..varname.." нет в строке!")
						return false
					end
	
				-- Есть конструкция с пользовательскими заменами переменных
				elseif
					CFGuser.vars and 
					(
						(CFGuser.vars[varname]) or (
							varname == "veh" and
							-- для veh другие переменные
							(CFGuser.vars["vehname"] or CFGuser.vars["vehid"])
						)
					)
				then
					if varname ~= "veh" then
						-- Заменить, если нужно будет не учитывать регистр
						-- в значениях пользовательских переменных.
						newSound = CFGuser.vars[varname] [vars[varname]]
						if newSound then
							sound = newSound
						else
							print("Warning! В vars."..varname.." нет значения "..vars[varname]..". "..
								"Переменная не перезаписалась.")
						end
					end
	
					-- Обработка значения переменных как звука.
					-- По сути та же функция как в else ниже.
					-- Нужно упростить.
					-- А также протестить. Загадка от Жака Фреско.
					if varname == "area" then
						local area = sound
						sound = getAreaSoundPatch(area)
						if not sound then
							print("Ошибка в звуке \"@area\" (№"..i..") в user эвенте \""..CFGuser.name.."\"!")
							print("После замены на пользовательскую конструкцию, район "..area.." не был найден.")
							return false
						end
					elseif varname == "veh" then
						if vars["vehname"] or vars["vehid"] then
							-- Хм... Как же упростить.
							-- Загадка от жака Фреско.
							-- А не похуй ли?
							if CFGuser.vars["vehname"] then
								local newSound = CFGuser.vars.vehname[vars.vehname]
								if newSound then
									vars.vehname = newSound
								end
							end
							if CFGuser.vars["vehid"] then
								local newSound = CFGuser.vars.vehid[vars.vehid]
								if newSound then
									vars.vehid = newSound
								end
							end
	
							vars.vehid = vars.vehid or vars.vehname and getCarModelByName(vars.vehname)
							sound = getVehSound(vars.vehid)
	
							if not sound then
								print("Ошибка в звуке \"@veh\" (№"..i..") в user эвенте \""..CFGuser.name.."\"!")
								if vars.vehid then
									print("Автомобиль с id \""..tostring(vars.vehid).."\" не был найден!")
								elseif vars.vehname then
									print("Автомобиль с названием \""..tostring(vars.vehname).."\" не был найден!")
								end
								return false
							end
	
							if vars.vehname and vars.vehname == CFGuser.vehOnFoot then
								sound = DISPATCH_SOUNDS.suspect.onFoot
							elseif vars.id or vars.nick then
								-- Берем инфу из игрока, если тот в стриме.
								vars.id = tonumber(vars.id) or sampGetPlayerIdByNickname(vars.nick)
								res, vars.vehid, vars.vehcolor = getModelIdAndColorByPlayerId(vars.id)
								if res then
									for _, soundColor in ipairs(getCarColorSound(vars.vehcolor)) do
										table.insert(arrSounds, soundColor)
									end
	
									sound = getVehSound(vars.vehid)
								end
							end
						else
							print("Ошибка в звуке \"@area\" (№"..i..") в user эвенте \""..CFGuser.name.."\"!")
							print("Переменной @vehname или @vehid нет в строке!")
							return false
						end
					else
						if type(sound) ~= "string" then
							print("Ошибка в звуке \""..tostring(sound).."\" (№"..i..") в user эвенте \""..CFGuser.name.."\"!")
							print("Значение переменной должна быть строка!")
							return false
						elseif sound:find("^DISP%.") then
							local s = sound:split("%.")
							local newSound
							if #s == 3 then
								if s[2] == "codes" or s[2] == "codesWithIn" then
									s[3] = tonumber(s[3])
								end
								newSound = DISPATCH_SOUNDS[s[2]][s[3]]
							else
								newSound = DISPATCH_SOUNDS[s[2]]
							end
	
							if not newSound then
								print("Ошибка в звуке \""..sound.."\" (№"..i..") в user эвенте \""..CFGuser.name.."\"!")
								print("Звук не найден! Убедитесь что вы все верно написали.")
								print("Сравните свои ключи с ключами в переменной DISPATCH_SOUNDS в файле config.lua.")
								print("Регистр символов имеет значение!")
								return false
							end
							sound = newSound
						else
							sound = PATH.audio..newSound
						end
					end
	
				else
					if varname == "area" then
						sound = getAreaSoundPatch(vars.area)
						if not sound then
							print("Ошибка в звуке №"..i.." в user эвенте \""..CFGuser.name.."\"!")
							print("@area не найдено.")
							return false
						end
	
					elseif varname == "veh" then
						-- Почему не берется инфа из возможного игрока
						-- в зоне стрима
						if vars["vehname"] or vars["vehid"] then
							vars.vehid = vars.vehid or vars.vehname and getCarModelByName(vars.vehname)
							sound = getVehSound(vars.vehid)
							if not sound then
								print("Ошибка в звуке \"@veh\" (№"..i..") в user эвенте \""..CFGuser.name.."\"!")
								if vars.vehid then
									print("Автомобиль с id \""..tostring(vars.vehid).."\" не был найден!")
								elseif vars.vehname then
									print("Автомобиль с названием \""..tostring(vars.vehname).."\" не был найден!")
								end
								return false
							end
	
							if CFGuser.veh and vars.vehname == CFGuser.vehOnFoot then
								sound = DISPATCH_SOUNDS.suspect.onFoot
							elseif vars.id or vars.nick then
								-- Берем инфу из игрока, если тот в стриме.
								vars.id = tonumber(vars.id) or sampGetPlayerIdByNickname(vars.nick)
								res, vars.vehid, vars.vehcolor = getModelIdAndColorByPlayerId(vars.id)
	
								if res then
									for _, soundColor in ipairs(getCarColorSound(vars.vehcolor)) do
										table.insert(arrSounds, soundColor)
									end
									sound = getVehSound(vars.vehid)
								end
							end
						else
							print("Ошибка в звуке №"..i.." в user эвенте \""..CFGuser.name.."\"!")
							print("Невозможно получить звук автомобиля, так как ...")
							print("... в паттерне не указана ни @vehname, ни @vehid!")
							return false
						end
					else
						sound = vars[varname]
					end
				end
			-- относительный путь
			elseif sound:find("%.") then
				sound = sound:gsub("/", "\\")
				sound = PATH.audio..sound
			else
				print("Неизвестный звук \""..sound.."\" (№"..i..") в user эвенте \""..CFGuser.name.."\"!")
				return false
			end
	
			arrSounds[#arrSounds+1] = sound
		end


		if type(arrSounds) == "table" and #arrSounds > 0 then
			lua_thread.create(playSounds, arrSounds, "userVolume", CFG.user[idUserEvent].isPlayRadioOn)
			return
		else
			print("Произошла ошибка в массиве \"sounds\" в пользовательском эвенте "..CFG.user[idUserEvent].name..", либо он не определён.!")
			return false
		end
	end

	if eventType == "call" then
		lua_thread.create(playSounds, {
			PATH.audio.."dispatcher_calls_units/we got a 10-.wav",
			randomChoice(DISPATCH_SOUNDS.codesWithIn),
			getAreaSoundPatch(vars.area)
		}, "callsVolume", true)

	elseif eventType == "areaAndCode" then
		lua_thread.create(playSounds, PATH.audio..PATH.areaAndCode..vars.area..".wav", "callsVolume")

	elseif eventType == "find" then
		lua_thread.create(playSounds, {
			DISPATCH_SOUNDS.suspect.lastSeen,
			DISPATCH_SOUNDS.words.inA,
			getAreaSoundPatch(vars.area),
			(
				vars["vehid"] and DISPATCH_SOUNDS.words.onA or
				vars["onFoot"] and DISPATCH_SOUNDS.suspect.onFoot or
				nil
			),
			unpack(getCarColorSound(vars.vehcolor)),
			getVehSound(vars.vehid)
		}, "findVolume", true)

	elseif eventType == "code1" then
		lua_thread.create(playSounds, randomChoice(CODE_1_SOUNDS), "radioVolume")

	elseif eventType == "code0" then
		lua_thread.create(playSounds, randomChoice(CODE_0_SOUNDS), "radioVolume")
	end

	return true
end

function getPatternWithoutVars(pattern)
	return pattern:gsub("@([%a_]+)", ".+")
end

function playSounds(array, volume, isPlayRadioOn)
	-- только в lua_thread
	array = toTable(array)

	while DISP_IS_SPEAK do wait(0) if IS_CLEAN_QUEUE then return end end
	DISP_IS_SPEAK = true

	local radioOnSound
	if isPlayRadioOn then
		radioOnSound = loadAudioStream(DISPATCH_SOUNDS.radioOn)
		play(radioOnSound, volume)
		wait(350)
	end

	for _, sound in pairs(array) do
		if type(sound) == 'string' then
			sound = loadAudioStream(sound)
		end
		if sound then
			wait(play(sound, volume))
		end
	end

	if isPlayRadioOn then
		wait(300)
		play(radioOnSound, volume)
	end
	wait(800)

	DISP_IS_SPEAK = false
end

function play(sound, volume)
	--[[функция проигрывает звук sound с громкостью volume
	если параметр строка, то он берет громкость из ини файла
	а возвращает длинну данного звука в миллисекундах, 
	специально для функции wait(), 
	чтобы следующий звук в коде проигрался после этого.
	Получается: wait(play(loadAudioStream("find.mp3"), "find"))]]

	if tonumber(volume) then
		volume = tonumber(volume)
	elseif type(volume) == "string" then
		volume = INI.INI[volume]
	else
		volume = 1
	end

	setAudioStreamVolume(sound, volume)
	setAudioStreamState(sound, 1)
	return getAudioStreamLength(sound) * 1000 - 35
end

-- NEW GETTERS --
function getPlayerHandleOrIdByVariables(vars)
	local playerInStream, playerHandle

	playerId = vars["id"]
	if not playerId then
		playerId = sampGetPlayerIdByNickname(vars["nick"])
	end

	local _, ggId = sampGetPlayerIdByCharHandle(PLAYER_PED)
	if playerId ~= ggId then
		playerInStream, playerHandle = sampGetCharHandleBySampPlayerId(playerId)
	else
		playerInStream, playerHandle = true, PLAYER_PED
	end

	return playerInStream and playerHandle or playerId
end

function getVehicleDefinedSoundByVariables(vars)

end

-- OTHER GETTERS --
function getModelIdAndColorByPlayerId(id)
	local playerInStream, playerHandle

	local _, playerId = sampGetPlayerIdByCharHandle(PLAYER_PED)

	if id ~= playerId then
		playerInStream, playerHandle = sampGetCharHandleBySampPlayerId(id)
	else
		playerInStream, playerHandle = true, PLAYER_PED
	end

	if playerInStream and isCharInAnyCar(playerHandle) then
		local carHandle = storeCarCharIsInNoSave(playerHandle)
		local vehId = getCarModel(carHandle)
		local vehColor
		if CARS_WITH_DEF_COLOR[vehId] then
			vehColor = CARS_WITH_DEF_COLOR[vehId]
		elseif getCurrentVehiclePaintjob(carHandle) ~= -1 then
			vehColor = "Customize"
		elseif isValueIsInArray(vehId, CARS_TO_SOUND_TWO_COLORS) then
			local c1, c2 = getCarColours(carHandle)
			vehColor = {c1, c2}
		else
			vehColor, _ = getCarColours(carHandle)
		end

		return true, vehId, vehColor
	else
		return false
	end
end

function getMarkerArea(markerId)
	local markerPos
	for _, icon in ipairs(MAP_ICONS) do
		if icon.type == markerId then
			markerPos = icon.pos
			break
		end
	end
	if not markerPos then
		print("Не найдена позиция маркера с id "..markerId.."!")
		return false 
	end

	for i, v in ipairs(AREAS) do
		if (markerPos.x >= v[2]) and (markerPos.y >= v[3]) and (markerPos.x <= v[5]) and (markerPos.y <= v[6]) then
			return v[1]
		end
	end
end

function getPlayerCity(ped)
	if getCharActiveInterior(ped) ~= 0 then return "San Andreas" end

	local x, y, _ = getCharCoordinates(ped)
	local reversedAreasArray = cloneTable(AREAS)
	table.reverse(reversedAreasArray)

	for i, v in ipairs(reversedAreasArray) do
		if (x >= v[2]) and (y >= v[3]) and (x <= v[5]) and (y <= v[6]) then
			return v[1]
		end
	end
end

function getPlayerArea(ped)
	if getCharActiveInterior(ped) ~= 0 then return "San Andreas" end
	local x, y, _ = getCharCoordinates(ped)
	for i, v in ipairs(AREAS) do
		if (x >= v[2]) and (y >= v[3]) and (x <= v[5]) and (y <= v[6]) then
			return v[1]
		end
	end
end

-- GETTERS SOUNDS --
function getCarModelByName(nameModel)
	for id, name in pairs(CAR_NAMES) do
		if name:tolower() == nameModel:tolower() then
			return id
		end
	end
	-- пользовательские
	if CFG.serverConfig then
		for name, id in pairs(CFG.serverConfig.vehNames) do
			if name:tolower() == nameModel:tolower() then
				return id
			end
		end
	end
end

function getVehSound(modelCarId)
	for class, arrayIds in pairs(CARS) do
		for _, idModel in ipairs(arrayIds) do
			if idModel == modelCarId then
				return loadAudioStream(PATH.audio..PATH.vehicles..class..".wav")
			end
		end
	end
end

function getCarColorSound(color)
	-- Возвращает массив
	if type(color) == "string" then
		return {loadAudioStream(PATH.audio..PATH.colors..color..".wav")}
	end

	color = toTable(color)
	local sounds = {}
	local firstColor

	-- Если двойной цвет
	for _, c in ipairs(color) do
		if c ~= "Not sound" then

			for colorName, colorsArray in pairs(COLORS) do
				for _, idColor in ipairs(colorsArray) do
					if c == idColor then
						local t = colorName:split(" ")
						if t[#t] ~= firstColor then
							-- Есть light/dark
							if #t == 2 then
								sounds[#sounds+1] = loadAudioStream(
									PATH.audio..PATH.colors..t[1]..".wav"
								)
							end
							sounds[#sounds+1] = loadAudioStream(
								PATH.audio..PATH.colors..t[#t]..".wav"
							)
							firstColor = t[#t]
						end
					end

				end
			end

		end
	end

	return sounds
end

function getAreaSoundPatch(area)
	area = area:gsub("-", " "):gsub("_", " "):gsub("\"", ""):gsub("\'", "")

	local patch = PATH.audio..PATH.area..area..".wav"
	if doesFileExist(patch) then
		return patch
	else
		local newArea = AREAS_NOT_VOICED[area:tolower()]

		-- пользовательские
		if not newArea and CFG.serverConfig and CFG.serverConfig.areas then
			for name, ar in pairs(CFG.serverConfig.areas) do
				if name:tolower() == area:tolower() then
					newArea = ar
				end
			end
		end

		if newArea then
			return getAreaSoundPatch(newArea)
		else
			print("Района \""..area.."\" не найдено.")
			return false
		end
	end
end

-- ICONS ON MAP --
-- иконка на карте (id: стандартный)
function sampev.onSetMapIcon(id, pos, typeIcon, color, style)
	-- print("onSetMapIcon id="..id..", type="..typeIcon..", ("..pos.x..", "..pos.y..")")
	MAP_ICONS[#MAP_ICONS+1] = {
		id=id, 
		pos=pos, 
		type=typeIcon
	}
end

function sampev.onRemoveMapIcon(id)
	-- print("onRemoveMapIcon id="..id)
	for i, icon in ipairs(MAP_ICONS) do
		if icon.id == id then
			MAP_ICONS[i] = nil
		end
	end
end

-- красная метка (id: 1)
function sampev.onSetCheckpoint(pos, radius)
	-- print("onSetCheckpoint ("..pos.x..", "..pos.y..")")
	-- Удаляем предыдущую метку
	for i, icon in ipairs(MAP_ICONS) do
		if icon.id == "checkpoint" then
			MAP_ICONS[i] = nil
			break
		end
	end

	MAP_ICONS[#MAP_ICONS+1] = {
		id="checkpoint",
		pos=pos,
		type=1
	}
end

function sampev.onDisableCheckpoint()
	-- print("onDisableCheckpoint")
	for i, icon in ipairs(MAP_ICONS) do
		if icon.id == "checkpoint" then
			MAP_ICONS[i] = nil
		end
	end
end

-- гоночный чекпоинт (id: 2)
function sampev.onSetRaceCheckpoint(type, pos, nextPos, size)
	-- print("onSetRaceCheckpoint ("..pos.x..", "..pos.y..")")
	-- Удаляем предыдущую метку
	for i, icon in ipairs(MAP_ICONS) do
		if icon.id == "racecheckpoint" then
			MAP_ICONS[i] = nil
			break
		end
	end

	MAP_ICONS[#MAP_ICONS+1] = {
		id="racecheckpoint",
		pos=pos,
		type=2
	}
end

function sampev.onDisableRaceCheckpoint()
	-- print("onDisableRaceCheckpoint")
	for i, icon in ipairs(MAP_ICONS) do
		if icon.id == "racecheckpoint" then
			MAP_ICONS[i] = nil
		end
	end
end

-- HELP FUNCTIONS --
function isValueIsInArray(value, arr, isRegEx)
	for i, element in pairs(arr) do
		if type(i) == "string" then
			element = i
		end
		if type(value) == "string" and string.find(value:tolower(), element:tolower(), 1, not isRegEx) then
			return true
		elseif value == element then
			return true
		end
	end
	return false
end

function varInElementsArray(var, arr)
	for _, el in pairs(arr) do
		if string.find(el:tolower(), var:tolower(), 1, true) then
			return true
		end
	end
	return false
end

function randomChoice(arr)
	-- возвращает случайный элемент arr
	if #arr == 0 then
		local iter = 0
		newArr = {}
		for i, it in pairs(arr) do
			iter = iter + 1
			newArr[iter] = it
		end
		arr = newArr
	end
	math.randomseed(os.time())
	return arr[math.random(#arr)]
end

function string:split(sep)
	if sep == nil then
		sep = "%s"
	end
	local t={}
	for str in string.gmatch(self, "([^"..sep.."]+)") do
		t[#t+1] = str
	end
	return t
end

function toTable(var)
	if type(var) ~= "table" then
		return {var}
	else
		return var
	end
end

function cloneTable(t)
    if type(t) ~= "table" then return t end
    local meta = getmetatable(t)
    local target = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            target[k] = cloneTable(v)
        else
            target[k] = v
        end
    end
    setmetatable(target, meta)
    return target
end

function table.reverse(t)
	for i = 1, math.floor(#t/2) do
		v = t[i]
		t[i] = t[#t-i+1]
		t[#t-i+1] = v
	end
end

function sampGetPlayerIdByNickname(nick)
    local _, myid = sampGetPlayerIdByCharHandle(playerPed)
    if tostring(nick) == sampGetPlayerNickname(myid) then return myid end
    for i = 0, 1000 do if sampIsPlayerConnected(i) and sampGetPlayerNickname(i) == tostring(nick) then return i end end
end

-- OTHER FUNCTIONS --
function mainMenu()
	local btn1 = u8:decode("Выбрать")
	local btn2 = u8:decode("Отмена")
	
	local text = string.format(
		"Скрипт:\t%s\n".. -- 0
		"Проверка обновлений\t%s\n".. -- 1
		"Воспроизводить в АФК\t%s\n".. -- 2
		"Громкость {FF4400}вызовов 911:\t{FFFFFF}%s\n".. -- 3
		"Громкость {ABCDEF}/find:\t{FFFFFF}%s\n".. -- 4
		"Громкость {8D8DFF}/r:\t{FFFFFF}%s\n".. -- 5
		"Громкость {66DDAA}user-эвентов:\t{FFFFFF}%s\n".. -- 6
		"  \n".. -- 7
		"Отключение {66DDAA}user-эвентов\n".. -- 8
		"Проверка паттерна\n".. -- 9
		"Очистить очередь воспроизведения\n".. -- 10
		"  \n".. -- 11
		"Страница скрипта", -- 12

		(INI.INI.state and "{21C90E}Вкл." or "{C91A14}Откл."),
		(INI.INI.isCheckUpdates and "{21C90E}Вкл." or "{C91A14}Откл."),
		(INI.INI.soundInAFK and "{21C90E}Вкл." or "{C91A14}Откл."),
		(INI.INI.callsVolume == 0 and "{C91A14}Откл." or INI.INI.callsVolume), 
		(INI.INI.findVolume == 0 and "{C91A14}Откл." or INI.INI.findVolume),
		(INI.INI.radioVolume == 0 and "{C91A14}Откл." or INI.INI.radioVolume),
		(INI.INI.userVolume == 0 and "{C91A14}Откл." or INI.INI.userVolume)
	)
	title = u8:decode("Настройки - PD Radio v"..thisScript().version.." | "..CFG.configInfo.name)
	sampShowDialog(20000, title, u8:decode(text), btn1, btn2, 4)
end

function saveIni()
	inicfg.save(INI, PATH.config.."config.ini")
end

BLAGODARNOSTI = [[В разработке скрипта учавствовали: Влад Чередниченко, Дмитрий Холодный (!), ]]