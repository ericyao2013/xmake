--!A cross-platform build utility based on Lua
--
-- Licensed to the Apache Software Foundation (ASF) under one
-- or more contributor license agreements.  See the NOTICE file
-- distributed with this work for additional information
-- regarding copyright ownership.  The ASF licenses this file
-- to you under the Apache License, Version 2.0 (the
-- "License"); you may not use this file except in compliance
-- with the License.  You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- 
-- Copyright (C) 2015 - 2018, TBOOX Open Source Group.
--
-- @author      ruki
-- @file        uninstall.lua
--

-- imports
import("core.base.task")
import("core.project.rule")
import("core.project.project")

-- uninstall binary
function _uninstall_binary(target)

    -- is phony target?
    if target:isphony() then
        return 
    end

    -- the binary directory
    local binarydir = path.join(_g.installdir, "bin")

    -- remove the target file
    os.rm(path.join(binarydir, path.filename(target:targetfile())))
end

-- uninstall library
function _uninstall_library(target)

    -- is phony target?
    if target:isphony() then
        return 
    end

    -- the library directory
    local librarydir = path.join(_g.installdir, "lib")

    -- the include directory
    local includedir = path.join(_g.installdir, "include")

    -- remove the target file
    os.rm(path.join(librarydir, path.filename(target:targetfile())))

    -- reove the config.h from the include directory
    local _, configheader = target:configheader(includedir)
    if configheader then
        os.rm(configheader) 
    end

    -- remove headers from the include directory
    local _, dstheaders = target:headerfiles(includedir)
    for _, dstheader in ipairs(dstheaders) do
        os.rm(dstheader)
    end
end

-- uninstall target
function _on_uninstall(target)

    -- build target with rules
    local done = false
    for _, r in ipairs(target:orderules()) do
        local on_uninstall = r:script("uninstall")
        if on_uninstall then
            on_uninstall(target)
            done = true
        end
    end
    if done then return end

    -- the scripts
    local scripts =
    {
        binary = _uninstall_binary
    ,   static = _uninstall_library
    ,   shared = _uninstall_library
    }

    -- call script
    local script = scripts[target:get("kind")]
    if script then
        script(target)
    end
end

-- uninstall the given target 
function _uninstall_target(target)

    -- enter project directory
    local oldir = os.cd(project.directory())

    -- the target scripts
    local scripts =
    {
        target:script("uninstall_before")
    ,   function (target)
            for _, r in ipairs(target:orderules()) do
                local before_uninstall = r:script("uninstall_before")
                if before_uninstall then
                    before_uninstall(target)
                end
            end
        end
    ,   target:script("uninstall", _on_uninstall)
    ,   function (target)
            for _, r in ipairs(target:orderules()) do
                local after_uninstall = r:script("uninstall_after")
                if after_uninstall then
                    after_uninstall(target)
                end
            end
        end
    ,   target:script("uninstall_after")
    }

    -- uninstall the target scripts
    for i = 1, 5 do
        local script = scripts[i]
        if script ~= nil then
            script(target)
        end
    end

    -- leave project directory
    os.cd(oldir)
end

-- uninstall the given target and deps
function _uninstall_target_and_deps(target)

    -- this target have been finished?
    if _g.finished[target:name()] then
        return 
    end

    -- uninstall for all dependent targets
    for _, depname in ipairs(target:get("deps")) do
        _uninstall_target_and_deps(project.target(depname)) 
    end

    -- uninstall target
    _uninstall_target(target)

    -- finished
    _g.finished[target:name()] = true
end

-- uninstall
function main(targetname, installdir)

    -- init finished states
    _g.finished = {}

    -- init install directory
    _g.installdir = installdir

    -- uninstall given target?
    if targetname then
        _uninstall_target_and_deps(project.target(targetname))
    else
        -- uninstall all targets
        for _, target in pairs(project.targets()) do
            _uninstall_target_and_deps(target)
        end
    end
end
