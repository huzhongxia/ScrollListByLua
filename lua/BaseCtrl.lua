BaseCtrl = class('BaseCtrl')

function BaseCtrl:ctor()
	self._name = '' -- 列表的名字，用于一个界面多个列表时区分不同的列表，在Window创建控件的时候会自动设置name和delegate
	self._delegate = nil -- 回调委托类
end

function BaseCtrl:_GetFunction(funcName)
    if self._delegate == nil then return nil end

    -- 优先选取特例化的名字
    if self._delegate[funcName .. '_' .. self._name] then
        return self._delegate[funcName .. '_' .. self._name]
    end

    -- 选取通用名字
    if self._delegate[funcName] then
        return self._delegate[funcName]
    end
end

function BaseCtrl:SetVisible(visible)
end

function BaseCtrl:IsVisible()
end
