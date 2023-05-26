--[[
lua中面向对象的实现，会自动调用父类的ctor，类是静态的概念，是全局唯一的，而对象是通过new创建出来的，是可以有任意多个的
一个类可以定义为全局变量，也可以定义为局部变量，这里并没有强制限制，不过如果类有复杂的继承关系，那么推荐定义为全局变量以便可以显示调用基类的函数

定义出的class实际数据分为三个部分：
1、ctor中定义的变量，它会直接在self中，因为derive_variable传递的表就是当前表
2、当前类定义的函数，它会在__class中，函数是共享且通用的，所以在class返回的对象中
3、父类定义的函数，它会在__supers中，如果多层继承则会保持这个嵌套关系

ps1:
1、由于变量是归属于对象的，避免复杂继承关系下变量数据混乱。同时访问速度更快。
2、函数是使用metatable访问的，一方面避免内存浪费（从逻辑上说函数就应该跟类型而不是对象关联在一起），另一方面可以方便的进行热加载（直接替换基类函数即可，不需要关心具体对象）
   不过缺点是基于metatable访问速度有所降低

ps2:
1、注意基类函数的调用方式是 self.super.XXXXX(self, xx)，使用点调用并且把self传递进去
self.super:DoFunc() 此时lua语法糖传递的self其实是super，而这个时候我们实际想传递的其实是self。
所以super的调用方式应该是self.super.DoFunc(self)，这样就可以保证self就是最终的对象，所有函数都可以准确找到其实现
然而如果有三层继承，那么这样调用其实也存在问题，因为DoFunc传递了self，那么如果第二层调用依然调用self.super.DoFunc(self)，那么就会出现死循环，因为这里的self永远为最终的对象。
所以这时候应该直接使用类名执行函数调用，而不应该用self.super
2、不需要考虑继承自userdata的情况，因为这样存在较大的性能隐患，我们应该从设计上避免这种实现
3、metatable设置为table比设置为function要快很多
4、函数是基于metatable的，而这个是所有对象共有的。变量是每个对象独有的，这样可以防止不同对象之间的属性冲突，尤其是多层继承的时候
]]

local getmetatable = getmetatable
local setmetatable = setmetatable
local table = table
local type = type
local rawget = rawget
local rawset = rawset

-- 获取一个类的所有基类
local function super_classes(class)
    -- 修改：没有用class.super_classes而是用rawget，原因是这里的目标仅是class自己是否有super_classes字段
    -- 不应该去父类查询，所以用rawget
    -- 可能导致的问题是，如果classB继承自classA，先执行classA.new()，再执行classB.new()，在classB.new()执行到这里的时候，
    -- 会查询到classA的super_classes字段，返回空表，导致没有调用父类的构造函数
    local super_classes = rawget(class, 'super_classes')
    if super_classes then
        return super_classes
    end

    super_classes = {}
    local super = class.super
    while super do
        table.insert(super_classes, super)
        super = super.super
    end

    -- 修改；和rawget对应，用rawset
    rawset(class, 'super_classes', super_classes)
    --class.super_classes = super_classes
    return super_classes
end

-- 依次调用构造函数，因为传递的是object，所以可以保证定义的所有变量都在最终的对象上（即self上，访问这些属性是不需要经过metatable的）
local function derive_variable(object, class, ...)
    local supers = super_classes(class)
    for i=#supers, 1, -1 do
        supers[i].ctor(object, ...)
    end
    class.ctor(object, ...)
end

-- 定义一个类
function class(class_name, super)
    local new_class = {}
    new_class.__cname = class_name  -- 类名，用于类型判定
    new_class.super = super

    -- 在前面调用，否则设置完metatable后，只要父类有ctor则无法判定子类是否实现了ctor
    if not new_class.ctor then
        -- add default constructor
        new_class.ctor = function() end
    end

    -- 基类的函数访问
    if super then
        setmetatable(new_class, { __index = super })
    end

    -- 公共的metatable保存在类对象中，避免new的时候重复创建
    new_class.__meta = { __index = new_class }

    new_class.new = function (...)
                        local object = {}
                        object.__class = new_class
                        setmetatable(object, new_class.__meta)
                        derive_variable(object, new_class, ...)
                        return object
                    end
	new_class.__call = function (self,...) return self:new(...) end
    return new_class
end

local iskindof_
iskindof_ = function(cls, name)
    -- 此处使用rawget以绕过__index
    local __index = rawget(cls, "__index")
    if type(__index) == "table" and rawget(__index, "__cname") == name then return true end

    if rawget(cls, "__cname") == name then return true end
    local supers = rawget(cls, "super")
    if not supers then return false end
    for _, super in ipairs(supers) do
        if iskindof_(super, name) then return true end
    end
    return false
end

-- 判定对象类型 考虑继承
function iskindof(obj, classname)
    local t = type(obj)
    if t ~= "table" and t ~= "userdata" then return false end

    if t == "userdata" then
        -- c#的类型 classname传递的是类型，如typeof(Actor)
        local objType = obj:GetType()
        return objType == classname or objType:IsSubClassOf(classname)
    else
        -- lua的类型，直接根据class传递的类型名来判定
        local mt = getmetatable(obj)
        if mt then
            return iskindof_(mt, classname)
        end
    end
    return false
end

-- 克隆对象，深拷贝
function clone(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local newObject = {}
        lookup_table[object] = newObject
        for key, value in pairs(object) do
            newObject[_copy(key)] = _copy(value)
        end
        return setmetatable(newObject, getmetatable(object))
    end
    return _copy(object)
end
