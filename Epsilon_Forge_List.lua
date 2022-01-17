-- All UI code is basically lifted straight from the Epsilon_Phases addon by Michael Priebe (Chase), so all credit to him there

-- TODO: 
-- Delete confirmation

local utils = Epsilon.utils
local messages = utils.messages
local server = utils.server
local tabs = utils.tabs
local headers = utils.headers

local main = Epsilon.main
local container = main.forge
local npcListFrame = PhasesFrameInsetContainer3Container1;
npcListFrame:SetPoint("TOPLEFT", 0, -26);

local lastCheckedPhase = -1; -- default
local npcList = {};
local forgeList = {};
local filteredList = {};
local listState = "forge";

local next; -- these two buttons both need the scroll.selected.id, but the scroll frame update loop also needs these two buttons hence they are defined here
local go;

local function valueExists(array, valueName, value)
    local valueExists = false;
    for _, field in ipairs(array) do
        if field[valueName] == value then valueExists = true; end
    end
    return valueExists;
end

server.receive("PNPCS", function(message, channel, sender)
    local records = {string.split(Epsilon.record, message)};
    for _, record in pairs(records) do
        local id, field, guid = string.split(Epsilon.field, record);
        if id and field and guid then
            if type(npcList[id]) ~= "table" then npcList[id] = {}; end
            table.insert(npcList[id], {id = id, name = field, guid = guid});

            if not valueExists(forgeList, "id", id) then
                table.insert(forgeList,{
                    id = id, 
                    name = field, 
                    spawned = guid ~= "0"
                });
            end
        end
    end
end);

local scroll = CreateFrame("SCROLLFRAME", "$parentScrollFrame", npcListFrame,"EpsilonHybridScrollFrameTemplate");
HybridScrollFrame_CreateButtons(scroll, "EpsilonThreeButtonTemplate");
scroll:SetScript("OnUpdate", function(self)
    local offset = HybridScrollFrame_GetOffset(self);
    local max = listState == "forge" and #forgeList or listState == "filter" and
                    #filteredList or #npcList[listState];
    local buttons = self.buttons;
    if listState == "forge" or listState == "filter" then
        go:Disable();
    else
        go:Enable();
    end
    for i = 1, #buttons do
        local button = buttons[i];
        local localNpcList;
        if listState == "forge" then
            localNpcList = forgeList[offset + i];
        elseif listState == "filter" then
            localNpcList = filteredList[offset + i];
        else
            localNpcList = npcList[listState][offset + i];
        end
        if localNpcList then
            if localNpcList == self.selected then
                button:LockHighlight();
                if type(npcList[scroll.selected.id]) ~= "table" or listState ==
                    "forge" and not forgeList[offset + i].spawned then
                    next:Disable();
                elseif listState == "filter" or listState == "forge" and
                    forgeList[offset + i].spawned then
                    next:Enable();
                end
            else
                button:UnlockHighlight()
            end
            button.entry = localNpcList;
            button.left:SetText(localNpcList.id);
            button.middle:SetText(localNpcList.name);
            button.right:SetText(localNpcList.guid or 
                npcList[localNpcList.id] ~= null and forgeList[offset + i].spawned and "Press >" or
                npcList[localNpcList.id] ~= null and not forgeList[offset + i].spawned and "No spawns" or
                "Loading guids...");
            button:Show();
        else
            button:Hide();
        end
    end
    HybridScrollFrame_Update(self, 20 * max, 20);
end);

local header1 = CreateFrame("BUTTON", "$parentHeader1", npcListFrame,"WhoFrameColumnHeaderTemplate");
header1:SetPoint("BOTTOMLEFT", npcListFrame, "TOPLEFT");
header1:SetPoint("RIGHT", scroll.buttons[1].left);
header1:SetText("ID");
header1.Middle:SetWidth(header1:GetWidth() - 9);

local header2 = CreateFrame("BUTTON", "$parentHeader2", npcListFrame,"WhoFrameColumnHeaderTemplate");
header2:SetPoint("LEFT", header1, "RIGHT", -2, 0);
header2:SetPoint("RIGHT", scroll.buttons[1].middle, -2, 0);
header2:SetText("Name");
header2.Middle:SetWidth(header2:GetWidth() - 9);

local header3 = CreateFrame("BUTTON", "$parentHeader3", npcListFrame,"WhoFrameColumnHeaderTemplate");
header3:SetPoint("LEFT", header2, "RIGHT", -2, 0);
header3:SetPoint("RIGHT", scroll.buttons[1].right, -2, 0);
header3:SetText("GUID");
header3.Middle:SetWidth(header3:GetWidth() - 9);

local notfirst = false;
local function CreateSet(text, tooltip, name)
    local self = CreateFrame("BUTTON", "$parentMap", npcListFrame,"UIPanelButtonTemplate");
    if notfirst then
        self:SetPoint("RIGHT", notfirst, "LEFT");
    else
        self:SetPoint("BOTTOMRIGHT", main);
    end
    notfirst = self;
    self:SetWidth(container:GetWidth() / 6);
    self:SetText(text);
    self:SetFrameStrata("HIGH");
    MagicButton_OnLoad(self);
    self:RegisterEvent("MODIFIER_STATE_CHANGED");
    self:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR");
        GameTooltip:SetText(name or text);
        GameTooltip:AddLine(tooltip, nil, nil, nil, true);
        GameTooltip:Show();
    end);
    self:SetScript("OnLeave", function() GameTooltip:Hide() end);
    return self;
end;

local deleteConfirmation = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin);
deleteConfirmation:SetPoint("CENTER");
deleteConfirmation:SetSize(204, 116);
deleteConfirmation:SetMovable(true)
deleteConfirmation:EnableMouse(true)
deleteConfirmation:RegisterForDrag("LeftButton")
deleteConfirmation:SetScript("OnDragStart", frame.StartMoving)
deleteConfirmation:SetScript("OnDragStop", frame.StopMovingOrSizing)
deleteConfirmation:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 16,
    insets = {left = 4, right = 4, top = 4, bottom = 4}
});
deleteConfirmation:SetBackdropColor(0.1, 0.1, 0.1, 1);

local closeDeleteButton = CreateFrame("Button", nil, deleteConfirmation, "UIPanelCloseButton");
closeDeleteButton:SetPoint("TOPRIGHT",2,2);
closeDeleteButton:SetSize(32,32);
closeDeleteButton:SetScript("OnClick", function(self, button)
    deleteConfirmation:Hide();
end);

local deleteText = deleteConfirmation:CreateFontString(nil, "ARTWORK", "GameFontNormal");
deleteText:SetPoint("TOPLEFT", 16, -20);
deleteText:SetSize(172,48)

local deleteButton = CreateFrame("Button", nil, deleteConfirmation, "UIPanelButtonTemplate");
deleteButton:SetPoint("BOTTOMRIGHT",-2, 2);
deleteButton:SetSize(80, 40);
deleteButton:SetText("|cFFFF0000Delete");
deleteButton:SetScript("OnClick", function(self, button)
    if scroll.selected.guid then
        SendChatMessage(".npc delete " .. scroll.selected.guid);
    else
        SendChatMessage(".phase forge npc delete " .. scroll.selected.id)
    end
    deleteConfirmation:Hide();
end);

local cancelDeleteButton = CreateFrame("Button", nil, deleteConfirmation, "UIPanelButtonTemplate");
cancelDeleteButton:SetPoint("BOTTOMLEFT",2, 2);
cancelDeleteButton:SetSize(80, 40);
cancelDeleteButton:SetText("Cancel");
cancelDeleteButton:SetScript("OnClick", function(self, button)
    deleteConfirmation:Hide();
end);

deleteConfirmation:Hide();
local function setDeleteConfirmation()
    if scroll.selected.guid then
        deleteText:SetText("Are you sure you want to delete " .. scroll.selected.name .. ":" .. scroll.selected.guid .. "?")
    else
        deleteText:SetText("Are you sure you want to delete " .. scroll.selected.name .. "?")
    end
    deleteConfirmation:Show();
end;

local delete = CreateSet("Delete", "Deletes the NPC. |cFFFF0000Warning: This cannot be undone!")
delete:SetScript("OnClick", function(self)
    if scroll.selected and not IgnoreNPCDeleteWarning then
        setDeleteConfirmation();
    elseif scroll.selected  and IgnoreNPCDeleteWarning then
        if scroll.selected.guid then
            SendChatMessage(".npc delete " .. scroll.selected.guid);
        else
            SendChatMessage(".phase forge npc delete " .. scroll.selected.id)
        end
    else
        print("|cFFFFFF00No NPC selected.");
    end
end);

local spawn = CreateSet("Spawn", "Spawns an NPC.");
spawn:SetScript("OnClick", function(self)
    if scroll.selected then
        SendChatMessage(".npc sp " .. scroll.selected.id);
    else
        print("|cFFFFFF00No NPC selected.");
    end
end);

go = CreateSet("Go", "Go to NPC");
go:SetScript("OnClick", function(self)
    if scroll.selected then
        if scroll.selected.guid then
            SendChatMessage(".npc go " .. scroll.selected.guid);
        else
            print("|cFFFFFF00Select an NPC with a guid.");
        end
    else
        print("|cFFFFFF00No NPC selected.");
    end
end);

local previous = CreateFrame("BUTTON", "$parentPrevPageButton", npcListFrame)
previous:Disable()
previous:SetSize(22, 22)
previous:SetPoint("BOTTOMLEFT", main)
previous:SetNormalTexture("Interface/Buttons/UI-SpellbookIcon-PrevPage-Up")
previous:GetNormalTexture():SetTexCoord(4 / 32, 27 / 32, 5 / 32, 27 / 32)
previous:SetPushedTexture("Interface/Buttons/UI-SpellbookIcon-PrevPage-Down")
previous:GetPushedTexture():SetTexCoord(4 / 32, 27 / 32, 5 / 32, 27 / 32)
previous:SetDisabledTexture(
    "Interface/Buttons/UI-SpellbookIcon-PrevPage-Disabled")
previous:GetDisabledTexture():SetTexCoord(4 / 32, 27 / 32, 5 / 32, 27 / 32)
previous:SetHighlightTexture("Interface/Buttons/UI-Common-MouseHilight", "ADD")
previous:GetHighlightTexture():SetTexCoord(4 / 32, 27 / 32, 5 / 32, 27 / 32)
previous:Disable();
MagicButton_OnLoad(previous)

previous:SetScript("OnClick", function(self)
    next:Enable();
    self:Disable();
    listState = "forge";
end)

next = CreateFrame("BUTTON", "$parentNextPageButton", npcListFrame)
next:SetSize(22, 22)
next:SetPoint("RIGHT", go, "LEFT")
next:SetNormalTexture("Interface/Buttons/UI-SpellbookIcon-NextPage-Up")
next:GetNormalTexture():SetTexCoord(4 / 32, 27 / 32, 5 / 32, 27 / 32)
next:SetPushedTexture("Interface/Buttons/UI-SpellbookIcon-NextPage-Down")
next:GetPushedTexture():SetTexCoord(4 / 32, 27 / 32, 5 / 32, 27 / 32)
next:SetDisabledTexture("Interface/Buttons/UI-SpellbookIcon-NextPage-Disabled")
next:GetDisabledTexture():SetTexCoord(4 / 32, 27 / 32, 5 / 32, 27 / 32)
next:SetHighlightTexture("Interface/Buttons/UI-Common-MouseHilight", "ADD")
next:GetHighlightTexture():SetTexCoord(4 / 32, 27 / 32, 5 / 32, 27 / 32)
next:Disable();
MagicButton_OnLoad(next);

next:SetScript("OnClick", function(self)
    previous:Enable()
    self:Disable();
    listState = scroll.selected.id or "forge";
end);

local refresh = CreateSet("","Refresh the NPC list. You will not be able to see NPCs if you are not a phase officer.","Refresh");
refresh:SetSize(22, 22);
refresh:SetPoint("TOPRIGHT", npcListFrame, 0, 50);
refresh:SetNormalTexture("Interface/Buttons/UI-RotationRight-Button-Up");
refresh:GetNormalTexture():SetTexCoord(4 / 32, 27 / 32, 5 / 32, 27 / 32);
refresh:SetPushedTexture("Interface/Buttons/UI-RotationRight-Button-Down");
refresh:GetPushedTexture():SetTexCoord(4 / 32, 27 / 32, 5 / 32, 27 / 32);
MagicButton_OnLoad(refresh);

refresh:SetScript("OnClick", function(self)
    npcList = {};
    forgeList = {};
    server.send("P_NPCS", "CLIENT_READY");
    listState = "forge";
end);

local search = CreateFrame("EditBox", "$parentSearch", npcListFrame,"SearchBoxTemplate");
search:SetHeight(20);
search:SetPoint("LEFT", previous, "RIGHT", 8, 0);
search:SetPoint("RIGHT", next, "LEFT", -4, 0);
search:SetFontObject("ChatFontNormal");

search:SetScript("OnEnterPressed", function(self)
    local filterText = search:GetText();
    if filterText == "" then
        listState = "forge";
    else
        filteredList = {};
        for _, npc in ipairs(forgeList) do
            if npc.id:lower():find(filterText:lower()) or
                npc.name:lower():find(filterText:lower()) then
                table.insert(filteredList, npc)
            end
        end
        listState = "filter";
    end
end);

npcListFrame:SetScript("OnShow", function()
    if lastCheckedPhase ~= Epsilon.currentPhase then
        npcList = {};
        forgeList = {};
        filteredList = {};
        listState = "forge";
        lastCheckedPhase = Epsilon.currentPhase;
        server.send("P_NPCS", "CLIENT_READY");
    end
end);