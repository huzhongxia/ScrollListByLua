-- 配合TableView使用，列表中的每个元素对应一个cell
---@class TableCell
TableCell = class('TableCell')

local Utils = Utils
local CSTypeName = CSTypeName
local IsFindChildComponentByTypeSupport = Utils.FindChildComponentByType ~= nil

function TableCell:ctor(go)
    self.index = -1                 -- 当前索引，外部如果在Button的回调函数中用到index，要使用cell.index，以避免闭包缓存参数的index
    self.spawnIndex = -1            -- 生成时刻的索引，这个创建之后就不会再变了。而index会随着滑动修改为对应的索引
    self.gameObject = go            -- gameObject
    self.transform = go.transform
    self.ctrlList = {}              -- 子控件列表

    self.hasSetParent = false       -- 一个标记，防止重复设置parent
end

-- 获取控件 componentType可以是CSType，也可以是类型名
function TableCell:GetChild(name, componentType)
    local ctrlSet = self.ctrlList[name]
    if ctrlSet == nil then
        ctrlSet = {}
        self.ctrlList[name] = ctrlSet
    end

    local ctrl = ctrlSet[componentType or 'GameObject']
    if ctrl then return ctrl end

    -- 这里没有直接用FindChild接口，主要是怕代码bug引起死循环
    if string.find(name, '.', 1, true) then
        name = string.gsub(name, '%.', '/')
    end

    if componentType ~= nil then
        -- 这里虽然有type的类型判定，但是都是在lua内，所以性能比较高，消耗可忽略
        if type(componentType) == 'string' then
            -- 用字符串类型的接口
            ctrl = Utils.FindChildComponent(self.transform, name, componentType)
        else
            if IsFindChildComponentByTypeSupport then
                -- 使用类型参数，性能更好
                ctrl = Utils.FindChildComponentByType(self.transform, name, componentType)
            else
                -- 不支持FindChildComponentByType这个接口的话，需要把类型转换成字符串
                ctrl = Utils.FindChildComponent(self.transform, name, CSTypeName[componentType])
            end
        end
    else
        ctrl = Utils.FindChild(self.transform, name)
    end

    ctrlSet[componentType or 'GameObject'] = ctrl

    return ctrl
end

function TableCell:GetText(name)
    return self:GetChild(name, CSType.TextMeshProUGUI)
end

function TableCell:GetImage(name)
    return self:GetChild(name, CSType.Image)
end

function TableCell:GetButton(name)
    return self:GetChild(name, CSType.UIButton)
end

-- 显示
function TableCell:Show()
    SetActive(self.gameObject, true)
end

-- 隐藏
function TableCell:Hide()
    SetActive(self.gameObject, false)
end

function TableCell:SetParent(parent)
    if self.hasSetParent then return end
    self.hasSetParent = true
    self.transform:SetParent(parent, false)
end

function TableCell:SetAnchoredPosition(x, y)
    self.transform:SetAnchoredPosition(x, y)
end

function TableCell:SetAnchoredPositionX(x)
    self.transform:SetAnchoredPositionX(x)
end

function TableCell:SetAnchoredPositionY(y)
    self.transform:SetAnchoredPositionT(y)
end

function TableCell:SetSizeDelta(x, y)
    self.transform:SetSizeDelta(x, y)
end

function TableCell:SetSizeDeltaX(x)
    self.transform:SetSizeDeltaX(x)
end

function TableCell:SetSizeDeltaY(y)
    self.transform:SetSizeDeltaY(y)
end

function TableCell:SetSize(width, height)
    self.transform:SetSize(width, height)
end

function TableCell:GetComponent(typeName)
    return self.gameObject:GetComponent(typeName)
end
