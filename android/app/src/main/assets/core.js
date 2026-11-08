/* Generated from canonical Harmony course modules. Run script/build_whaledo_android_core.cjs. */
(function(){'use strict';const modules={"engine/Types":function(require,module,exports){
"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.defaultData = exports.priorityColor = exports.muted = exports.card = exports.ink = exports.bg = exports.isDark = exports.remaining = exports.doneMinutes = exports.taskName = exports.hours = exports.parseLocalDateTime = exports.formatDate = exports.clock = exports.dateKey = exports.addDays = exports.dayStart = exports.errorText = exports.Failure = exports.cloneData = exports.uid = exports.LoadBucket = exports.PlanResult = exports.Unscheduled = exports.AppData = exports.ChatSession = exports.ChatMessage = exports.Settings = exports.PetLine = exports.AIConfig = exports.Course = exports.FreeWindow = exports.Block = exports.Task = exports.TaskWindow = exports.DAY = exports.MINUTE = void 0;
const AppTime_1 = require("../model/AppTime");
exports.MINUTE = 60000;
exports.DAY = 86400000;
class TaskWindow {
    constructor() {
        this.date = '';
        this.weekdays = [];
        this.startMinute = 480;
        this.endMinute = 1080;
    }
}
exports.TaskWindow = TaskWindow;
class Task {
    constructor() {
        this.id = '';
        this.parentId = '';
        this.kind = 'task';
        this.title = '';
        this.subject = '';
        this.note = '';
        this.deadline = 0;
        this.earliest = 0;
        this.minutes = 60;
        this.priority = 3;
        this.chunk = 45;
        this.splittable = true;
        this.archived = false;
        this.createdAt = 0;
        this.taskType = 'short';
        this.openEnded = false;
        this.windows = [];
    }
}
exports.Task = Task;
class Block {
    constructor() {
        this.id = '';
        this.taskId = '';
        this.start = 0;
        this.end = 0;
        this.locked = false;
        this.done = false;
        this.completedAt = 0;
        this.rating = 0;
        this.reflection = '';
    }
}
exports.Block = Block;
class FreeWindow {
    constructor() {
        this.id = '';
        this.weekday = 1;
        this.date = '';
        this.startMinute = 1080;
        this.endMinute = 1320;
    }
}
exports.FreeWindow = FreeWindow;
class Course {
    constructor() {
        this.id = '';
        this.title = '';
        this.location = '';
        this.start = 0;
        this.end = 0;
        this.weekdays = [];
        this.until = 0;
        this.weeks = [];
        this.source = 'manual';
        this.externalId = '';
    }
}
exports.Course = Course;
class AIConfig {
    constructor() {
        this.provider = '小艺';
        this.endpoint = '';
        this.model = '';
        this.protocol = 'openai';
        this.agentId = '';
        this.systemPrompt = '你是温和务实的课业安排助手。尊重学生的空闲、截止和休息，提出可执行的小步骤，不责备用户。';
    }
}
exports.AIConfig = AIConfig;
class PetLine {
    constructor() {
        this.event = 'idle';
        this.text = '';
    }
}
exports.PetLine = PetLine;
class Settings {
    constructor() {
        this.theme = 'system';
        this.systemDark = false;
        this.accent = '#6261DE';
        this.wallpaper = '';
        this.wallpaperOpacity = 0.18;
        this.termStart = 0;
        this.termWeeks = 20;
        this.horizonDays = 366;
        this.reminder = 'off';
        this.reminderLead = 10;
        this.reminderSent = [];
        this.petEnabled = true;
        this.petKind = 'cat';
        this.petImage = '';
        this.petSmart = false;
        this.petPrompt = '你是一只温柔的小猫学习伙伴。用简短、自然、体贴的话陪伴学习，不催促、不批评，提醒休息。';
        this.petLines = [];
        this.petOverlay = true;
        this.petRoam = false;
        this.petAutoHide = true;
        this.petDockSeconds = 15;
        this.petUseSharedModel = true;
        this.petProvider = '';
        this.petAI = new AIConfig();
        this.petSize = 76;
        this.calendarExports = [];
        this.productRevision = 0;
        this.ai = new AIConfig();
        this.aiConfigs = [];
    }
}
exports.Settings = Settings;
class ChatMessage {
    constructor() {
        this.id = '';
        this.role = 'user';
        this.content = '';
        this.createdAt = 0;
        this.proposal = '';
        this.proposalState = '';
        this.proposalRevision = 0;
    }
}
exports.ChatMessage = ChatMessage;
class ChatSession {
    constructor() {
        this.id = '';
        this.title = '新会话';
        this.createdAt = 0;
        this.updatedAt = 0;
        this.archived = false;
        this.messages = [];
        this.draft = '';
    }
}
exports.ChatSession = ChatSession;
class AppData {
    constructor() {
        this.version = 1;
        this.revision = 0;
        this.tasks = [];
        this.blocks = [];
        this.free = [];
        this.courses = [];
        this.settings = new Settings();
        this.messages = [];
        this.sessions = [];
        this.activeSessionId = '';
        this.planningRevision = 0;
        this.lastPlan = 0;
    }
}
exports.AppData = AppData;
class Unscheduled {
    constructor() {
        this.taskId = '';
        this.minutes = 0;
        this.reason = '';
    }
}
exports.Unscheduled = Unscheduled;
class PlanResult {
    constructor() {
        this.blocks = [];
        this.unmet = [];
        this.warnings = [];
        this.added = 0;
        this.moved = 0;
        this.preserved = 0;
    }
}
exports.PlanResult = PlanResult;
class LoadBucket {
    constructor() {
        this.start = 0;
        this.end = 0;
        this.planned = 0;
        this.done = 0;
        this.capacity = 0;
        this.deadlines = 0;
    }
}
exports.LoadBucket = LoadBucket;
function uid(prefix = 'id') {
    return `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}
exports.uid = uid;
function cloneData(data) { return JSON.parse(JSON.stringify(data)); }
exports.cloneData = cloneData;
class Failure {
}
exports.Failure = Failure;
function errorText(error) {
    if (error === null || error === undefined) {
        return '操作失败，请重试';
    }
    if (typeof error === 'string') {
        return String(error);
    }
    const value = error;
    const message = typeof value.message === 'string' ? value.message : '操作失败';
    return value.code === undefined ? message : `${message}（${value.code}）`;
}
exports.errorText = errorText;
function dayStart(time) { return AppTime_1.AppTime.dayStart(time); }
exports.dayStart = dayStart;
function addDays(time, count) { return AppTime_1.AppTime.addDays(time, count); }
exports.addDays = addDays;
function dateKey(time) {
    return AppTime_1.AppTime.dateKey(time);
}
exports.dateKey = dateKey;
function clock(time) { return AppTime_1.AppTime.clock(time); }
exports.clock = clock;
function formatDate(time) { return `${dateKey(time)} ${clock(time)}`; }
exports.formatDate = formatDate;
function parseLocalDateTime(text) {
    const input = text.trim();
    if (!/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$/.test(input)) {
        return NaN;
    }
    const time = Date.parse(input.replace(' ', 'T'));
    return Number.isFinite(time) && formatDate(time) === input ? time : NaN;
}
exports.parseLocalDateTime = parseLocalDateTime;
function hours(minutes) { return `${Math.round(minutes / 6) / 10}h`; }
exports.hours = hours;
function taskName(data, taskId) { const t = data.tasks.find((item) => item.id === taskId); return t === undefined ? '已删除的课业' : t.title; }
exports.taskName = taskName;
function doneMinutes(data, taskId) {
    return data.blocks.filter((b) => b.taskId === taskId && b.done).reduce((sum, b) => sum + (b.end - b.start) / exports.MINUTE, 0);
}
exports.doneMinutes = doneMinutes;
function remaining(data, task) { return Math.max(0, task.minutes - doneMinutes(data, task.id)); }
exports.remaining = remaining;
function isDark(data) { return data.settings.theme === 'dark' || (data.settings.theme === 'system' && data.settings.systemDark); }
exports.isDark = isDark;
function bg(data) { return isDark(data) ? '#141824' : '#F4F5FC'; }
exports.bg = bg;
function ink(data) { return isDark(data) ? '#F0F1FA' : '#252C46'; }
exports.ink = ink;
function card(data) { return isDark(data) ? '#E6222839' : '#EEFFFFFF'; }
exports.card = card;
function muted(data) { return isDark(data) ? '#A8B2CA' : '#768199'; }
exports.muted = muted;
function priorityColor(priority) { return priority >= 4.5 ? '#D96C73' : priority >= 3.5 ? '#C88C36' : priority >= 2.5 ? '#6261DE' : '#3F9B91'; }
exports.priorityColor = priorityColor;
function defaultData(now = Date.now()) {
    const d = new AppData();
    d.settings.termStart = dayStart(now);
    for (let weekday = 0; weekday < 7; weekday++) {
        const f = new FreeWindow();
        f.id = `default-${weekday}`;
        f.weekday = weekday;
        f.startMinute = weekday === 0 || weekday === 6 ? 9 * 60 : 18 * 60;
        f.endMinute = weekday === 0 || weekday === 6 ? 12 * 60 : 22 * 60;
        d.free.push(f);
    }
    const line = new PetLine();
    line.event = 'idle';
    line.text = '把大事拆成一小步，今天也可以从容一点。';
    d.settings.petLines.push(line);
    return d;
}
exports.defaultData = defaultData;

},
"engine/TaskRules":function(require,module,exports){
"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.taskAvailability = exports.taskWindowsValid = exports.durationMinutes = exports.minuteOfDay = exports.WindowDraft = exports.PhaseDraft = exports.TaskInterval = exports.OPEN_DEADLINE = void 0;
const Types_1 = require("./Types");
exports.OPEN_DEADLINE = new Date(2099, 11, 31, 23, 59).getTime();
class TaskInterval {
    constructor() {
        this.start = 0;
        this.end = 0;
    }
}
exports.TaskInterval = TaskInterval;
class PhaseDraft {
    constructor() {
        this.id = '';
        this.title = '';
        this.start = '';
        this.end = '';
        this.effort = '30';
        this.unit = '分钟';
    }
}
exports.PhaseDraft = PhaseDraft;
class WindowDraft {
    constructor() {
        this.dated = false;
        this.date = '';
        this.days = [1, 2, 3, 4, 5];
        this.start = '18:00';
        this.end = '20:00';
    }
}
exports.WindowDraft = WindowDraft;
function minuteOfDay(value) { if (!/^\d{2}:\d{2}$/.test(value)) {
    return -1;
} const h = Number(value.slice(0, 2)), m = Number(value.slice(3)); return h >= 0 && h <= 24 && m >= 0 && m < 60 && (h !== 24 || m === 0) ? h * 60 + m : -1; }
exports.minuteOfDay = minuteOfDay;
function durationMinutes(value, unit) {
    if (!/^(?:\d+(?:\.\d+)?|\.\d+)$/.test(value.trim())) {
        throw new Error('请输入有效工作量');
    }
    const result = Number(value) * (unit === '小时' ? 60 : unit === '天' ? 1440 : 1);
    if (!Number.isInteger(result) || result < 15 || result > 525600) {
        throw new Error('工作量须折合15—525600整数分钟');
    }
    return result;
}
exports.durationMinutes = durationMinutes;
function taskWindowsValid(windows) {
    return Array.isArray(windows) && windows.length <= 16 && windows.every((w) => w !== null && typeof w.date === 'string' && (w.date === '' || Number.isFinite((0, Types_1.parseLocalDateTime)(`${w.date} 00:00`))) && Array.isArray(w.weekdays) && w.weekdays.length <= 7 && w.weekdays.every((n) => Number.isInteger(n) && n >= 0 && n <= 6) && (w.date !== '' || w.weekdays.length > 0) && Number.isInteger(w.startMinute) && Number.isInteger(w.endMinute) && w.startMinute >= 0 && w.endMinute <= 1440 && w.startMinute < w.endMinute);
}
exports.taskWindowsValid = taskWindowsValid;
function taskAvailability(task, from, to) {
    if (!task.windows || task.windows.length === 0) {
        return [{ start: from, end: to }];
    }
    const result = [];
    for (let day = (0, Types_1.dayStart)(from); day < to; day = (0, Types_1.addDays)(day, 1)) {
        const date = new Date(day);
        const key = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
        for (const w of task.windows) {
            if (w.date !== '' ? w.date !== key : !w.weekdays.includes(date.getDay())) {
                continue;
            }
            const start = Math.max(from, day + w.startMinute * Types_1.MINUTE), end = Math.min(to, day + w.endMinute * Types_1.MINUTE);
            if (end > start) {
                result.push({ start, end });
            }
        }
    }
    const sorted = result.sort((a, b) => a.start - b.start || a.end - b.end);
    const merged = [];
    for (const span of sorted) {
        const last = merged[merged.length - 1];
        if (last !== undefined && span.start <= last.end) {
            last.end = Math.max(last.end, span.end);
        }
        else {
            merged.push({ start: span.start, end: span.end });
        }
    }
    return merged;
}
exports.taskAvailability = taskAvailability;

},
"engine/Scheduler":function(require,module,exports){
"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.aggregate = exports.schedule = exports.subtractIntervals = exports.freeIntervals = exports.courseOccurrences = exports.validateTask = exports.effectiveEarliest = exports.effectiveDeadline = exports.overlap = exports.Interval = void 0;
const AppTime_1 = require("../model/AppTime");
const Types_1 = require("./Types");
const TaskRules_1 = require("./TaskRules");
class Interval {
    constructor() {
        this.start = 0;
        this.end = 0;
    }
}
exports.Interval = Interval;
function overlap(a, b) { return a.start < b.end && b.start < a.end; }
exports.overlap = overlap;
function effectiveDeadline(task, tasks) {
    let deadline = task.openEnded ? Number.MAX_SAFE_INTEGER : task.deadline;
    let parentId = task.parentId;
    const visited = [task.id];
    while (parentId !== '') {
        if (visited.includes(parentId)) {
            throw new Error('目标层级存在循环');
        }
        visited.push(parentId);
        const parent = tasks.find((t) => t.id === parentId);
        if (parent === undefined) {
            throw new Error('父目标不存在');
        }
        if (!parent.openEnded) {
            deadline = Math.min(deadline, parent.deadline);
        }
        parentId = parent.parentId;
    }
    return deadline;
}
exports.effectiveDeadline = effectiveDeadline;
function effectiveEarliest(task, tasks) {
    let earliest = task.earliest;
    let parentId = task.parentId;
    const visited = [task.id];
    while (parentId !== '') {
        if (visited.includes(parentId)) {
            throw new Error('目标层级循环');
        }
        visited.push(parentId);
        const parent = tasks.find((t) => t.id === parentId);
        if (parent === undefined) {
            throw new Error('父目标不存在');
        }
        earliest = Math.max(earliest, parent.earliest);
        parentId = parent.parentId;
    }
    return earliest;
}
exports.effectiveEarliest = effectiveEarliest;
function validateTask(task, tasks) {
    if (task.title.trim() === '') {
        return '请输入任务名称';
    }
    if (!Number.isFinite(task.deadline) || task.deadline <= 0 || !Number.isFinite(task.earliest) || task.earliest < 0) {
        return '请输入有效日期时间';
    }
    if (task.earliest >= task.deadline) {
        return '最早开始须早于截止时间';
    }
    if (!Number.isFinite(task.minutes) || task.minutes < 15 || task.minutes > 525600) {
        return '预计工作量须为 15—525600 分钟';
    }
    if (task.priority < 0.5 || task.priority > 5 || task.priority * 2 !== Math.round(task.priority * 2)) {
        return '重要度须为 0.5—5 星，以半星递增';
    }
    if (!Number.isFinite(task.chunk) || task.chunk < 15 || task.chunk > 480) {
        return '单次时长须为 15—480 分钟';
    }
    if (task.windows !== undefined && !(0, TaskRules_1.taskWindowsValid)(task.windows)) {
        return '可执行时段无效，最多16段';
    }
    try {
        if (effectiveDeadline(task, tasks) <= effectiveEarliest(task, tasks)) {
            return '父目标截止早于子任务开始时间';
        }
    }
    catch {
        return '目标层级无效或存在循环';
    }
    return '';
}
exports.validateTask = validateTask;
function courseOccurrences(data, from, to) {
    const result = [];
    for (const c of data.courses) {
        if (c.weekdays.length === 0) {
            if (c.start < to && c.end > from) {
                result.push({ start: c.start, end: c.end });
            }
            continue;
        }
        const anchor = AppTime_1.AppTime.view(c.start);
        const duration = c.end - c.start;
        for (let day = (0, Types_1.dayStart)(Math.max(from, c.start)); day < to; day = (0, Types_1.addDays)(day, 1)) {
            if (!c.weekdays.includes(AppTime_1.AppTime.weekday(day))) {
                continue;
            }
            const week = Math.floor(((0, Types_1.dayStart)(day) - (0, Types_1.dayStart)(data.settings.termStart)) / 604800000) + 1;
            if (c.weeks.length > 0 && !c.weeks.includes(week)) {
                continue;
            }
            const at = AppTime_1.AppTime.atMinute(day, anchor.getHours() * 60 + anchor.getMinutes());
            const start = at;
            if (start < c.start || (c.until > 0 && start > c.until)) {
                continue;
            }
            if (start < to && start + duration > from) {
                result.push({ start: start, end: start + duration });
            }
        }
    }
    return result;
}
exports.courseOccurrences = courseOccurrences;
function freeIntervals(data, from, to) {
    const raw = [];
    for (let day = (0, Types_1.dayStart)(from); day < to; day = (0, Types_1.addDays)(day, 1)) {
        const key = (0, Types_1.dateKey)(day), weekday = AppTime_1.AppTime.weekday(day);
        for (const f of data.free) {
            if (f.date !== '' ? f.date !== key : f.weekday !== weekday) {
                continue;
            }
            if (f.endMinute <= f.startMinute || f.startMinute < 0 || f.endMinute > 1440) {
                continue;
            }
            const start = Math.max(from, AppTime_1.AppTime.atMinute(day, f.startMinute));
            const end = Math.min(to, AppTime_1.AppTime.atMinute(day, f.endMinute));
            if (end > start) {
                raw.push({ start: start, end: end });
            }
        }
    }
    raw.sort((a, b) => a.start - b.start);
    const merged = [];
    for (const item of raw) {
        const last = merged[merged.length - 1];
        if (last !== undefined && item.start <= last.end) {
            last.end = Math.max(last.end, item.end);
        }
        else {
            merged.push({ start: item.start, end: item.end });
        }
    }
    return merged;
}
exports.freeIntervals = freeIntervals;
function subtractIntervals(windows, busy) {
    let available = windows;
    for (const event of busy) {
        const next = [];
        for (const w of available) {
            if (!overlap(w, event)) {
                next.push(w);
                continue;
            }
            if (event.start > w.start) {
                next.push({ start: w.start, end: Math.min(w.end, event.start) });
            }
            if (event.end < w.end) {
                next.push({ start: Math.max(w.start, event.end), end: w.end });
            }
        }
        available = next;
    }
    return available;
}
exports.subtractIntervals = subtractIntervals;
function schedule(data, now = Date.now()) {
    const result = new Types_1.PlanResult();
    const horizon = (0, Types_1.addDays)((0, Types_1.dayStart)(now), Math.max(1, Math.min(366, data.settings.horizonDays)));
    const preserved = data.blocks.filter((b) => b.done || b.locked || b.start < now);
    result.preserved = preserved.length;
    result.blocks = preserved.slice();
    const busy = courseOccurrences(data, now, horizon);
    for (const b of preserved) {
        if (b.end > now) {
            busy.push({ start: b.start, end: b.end });
        }
    }
    let slots = subtractIntervals(freeIntervals(data, Math.ceil(now / (15 * Types_1.MINUTE)) * 15 * Types_1.MINUTE, horizon), busy);
    const leaves = [];
    for (const task of data.tasks.filter((t) => !t.archived && t.kind !== 'goal' && (0, Types_1.remaining)(data, t) > 0)) {
        const problem = validateTask(task, data.tasks);
        if (problem !== '') {
            result.unmet.push({ taskId: task.id, minutes: (0, Types_1.remaining)(data, task), reason: problem });
        }
        else {
            leaves.push(task);
        }
    }
    // 截止和松弛时间优先；同等紧急度用重要度，最后用稳定 ID，保证确定性。
    leaves.sort((a, b) => {
        const ad = effectiveDeadline(a, data.tasks);
        const bd = effectiveDeadline(b, data.tasks);
        const slackA = (ad - now) / Types_1.MINUTE - (0, Types_1.remaining)(data, a) * 1.5;
        const slackB = (bd - now) / Types_1.MINUTE - (0, Types_1.remaining)(data, b) * 1.5;
        return (slackA - a.priority * 120) - (slackB - b.priority * 120) || ad - bd || b.priority - a.priority || a.id.localeCompare(b.id);
    });
    for (const task of leaves) {
        const validation = validateTask(task, data.tasks);
        if (validation !== '') {
            result.unmet.push({ taskId: task.id, minutes: (0, Types_1.remaining)(data, task), reason: validation });
            continue;
        }
        const deadline = effectiveDeadline(task, data.tasks);
        const committed = preserved.filter((b) => b.taskId === task.id && !b.done && b.end > now).reduce((sum, b) => sum + (b.end - b.start) / Types_1.MINUTE, 0);
        let needed = Math.max(0, (0, Types_1.remaining)(data, task) - committed);
        let serial = 0;
        while (needed > 0) {
            const required = task.splittable ? Math.min(task.chunk, needed) : needed;
            let found = -1;
            let start = 0;
            let duration = 0;
            for (let i = 0; i < slots.length; i++) {
                const candidates = (0, TaskRules_1.taskAvailability)(task, slots[i].start, Math.min(slots[i].end, deadline));
                for (const window of candidates) {
                    const begin = Math.ceil(Math.max(window.start, effectiveEarliest(task, data.tasks)) / (15 * Types_1.MINUTE)) * 15 * Types_1.MINUTE;
                    const available = Math.floor((Math.min(window.end, deadline) - begin) / Types_1.MINUTE);
                    if (available <= 0) {
                        continue;
                    }
                    const chunk = task.splittable ? Math.min(required, Math.floor(available / 15) * 15) : required;
                    if (chunk <= 0 || (!task.splittable && available < required)) {
                        continue;
                    }
                    if (chunk < Math.min(15, needed)) {
                        continue;
                    }
                    found = i;
                    start = begin;
                    duration = chunk;
                    break;
                }
                if (found >= 0) {
                    break;
                }
            }
            if (found < 0) {
                break;
            }
            const block = new Types_1.Block();
            block.id = `plan-${task.id}-${start}-${serial++}`;
            block.taskId = task.id;
            block.start = start;
            block.end = start + duration * Types_1.MINUTE;
            while (result.blocks.some((existing) => existing.id === block.id)) {
                block.id = `plan-${task.id}-${start}-${serial++}`;
            }
            result.blocks.push(block);
            needed -= duration;
            slots = subtractIntervals(slots, [{ start: block.start, end: block.end }]);
        }
        if (needed > 0) {
            result.unmet.push({ taskId: task.id, minutes: needed, reason: deadline <= now ? '截止已过' : '截止前空闲不足，或没有足够长的连续时段' });
        }
    }
    const planned = result.blocks.filter((b) => !preserved.includes(b));
    result.added = planned.filter((b) => !data.blocks.some((old) => old.taskId === b.taskId && old.start === b.start && old.end === b.end)).length;
    result.moved = data.blocks.filter((old) => !preserved.includes(old) && !planned.some((b) => b.taskId === old.taskId && b.start === old.start && b.end === old.end)).length;
    for (const b of preserved.filter((item) => item.locked && !item.done)) {
        const t = data.tasks.find((item) => item.id === b.taskId);
        if (t !== undefined && b.end > effectiveDeadline(t, data.tasks)) {
            result.warnings.push(`固定安排“${t.title}”超过截止，请手动调整`);
        }
        if (courseOccurrences(data, b.start, b.end).some((c) => overlap(c, { start: b.start, end: b.end }))) {
            result.warnings.push('固定安排与课表冲突，请手动调整');
        }
    }
    result.blocks.sort((a, b) => a.start - b.start || a.id.localeCompare(b.id));
    return result;
}
exports.schedule = schedule;
function aggregate(data, from, to, days) {
    const buckets = [];
    for (let start = from; start < to; start = (0, Types_1.addDays)(start, days)) {
        const end = Math.min(to, (0, Types_1.addDays)(start, days));
        const bucket = new Types_1.LoadBucket();
        bucket.start = start;
        bucket.end = end;
        for (const b of data.blocks) {
            const m = Math.max(0, Math.min(end, b.end) - Math.max(start, b.start)) / Types_1.MINUTE;
            bucket.planned += m;
            if (b.done) {
                bucket.done += m;
            }
        }
        bucket.capacity = subtractIntervals(freeIntervals(data, start, end), courseOccurrences(data, start, end)).reduce((sum, w) => sum + (w.end - w.start) / Types_1.MINUTE, 0);
        bucket.deadlines = data.tasks.filter((t) => !t.archived && t.kind !== 'goal' && t.deadline >= start && t.deadline < end).length;
        buckets.push(bucket);
    }
    return buckets;
}
exports.aggregate = aggregate;

},
"model/AppTime":function(require,module,exports){
"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AppTime = exports.zoneLabels = exports.zoneIds = void 0;
exports.zoneIds = ['Asia/Shanghai', 'UTC', 'Asia/Tokyo', 'Asia/Kolkata', 'Asia/Dubai', 'Europe/London', 'Europe/Paris', 'America/New_York', 'America/Los_Angeles', 'Australia/Sydney', 'Pacific/Auckland'];
exports.zoneLabels = ['北京 / 上海', '协调世界时 UTC', '东京', '新德里', '迪拜', '伦敦', '巴黎', '纽约', '洛杉矶', '悉尼', '奥克兰'];
class AppTime {
    static configure(resolve, systemZone) { AppTime.resolve = resolve; AppTime.systemZone = systemZone; }
    static offset(time, zone = AppTime.zone) { return AppTime.resolve(zone, time); }
    static civil(time, zone = AppTime.zone) { return new Date(time + AppTime.offset(time, zone)); }
    static fromCivil(stamp, zone = AppTime.zone) {
        const offsets = [];
        for (const delta of [-172800000, -86400000, 0, 86400000, 172800000]) {
            const offset = AppTime.offset(stamp + delta, zone);
            if (!offsets.includes(offset)) {
                offsets.push(offset);
            }
        }
        const matches = offsets.map((offset) => stamp - offset).filter((at) => at + AppTime.offset(at, zone) === stamp);
        if (matches.length !== 1) {
            throw new Error('目标时区的这个时间不存在或重复，请选择其它时间');
        }
        return matches[0];
    }
    static view(time, zone = AppTime.zone) {
        const c = AppTime.civil(time, zone);
        return new Date(c.getUTCFullYear(), c.getUTCMonth(), c.getUTCDate(), c.getUTCHours(), c.getUTCMinutes(), c.getUTCSeconds(), c.getUTCMilliseconds());
    }
    static fromView(date, zone = AppTime.zone) { return AppTime.fromCivil(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate(), date.getHours(), date.getMinutes(), date.getSeconds(), date.getMilliseconds()), zone); }
    static dayStart(time, zone = AppTime.zone) { const c = AppTime.civil(time, zone); return AppTime.fromCivil(Date.UTC(c.getUTCFullYear(), c.getUTCMonth(), c.getUTCDate()), zone); }
    static addDays(time, count, zone = AppTime.zone) { const c = AppTime.civil(time, zone); c.setUTCDate(c.getUTCDate() + count); return AppTime.fromCivil(c.getTime(), zone); }
    static atMinute(day, minute, zone = AppTime.zone) { const c = AppTime.civil(day, zone); return AppTime.fromCivil(Date.UTC(c.getUTCFullYear(), c.getUTCMonth(), c.getUTCDate(), Math.floor(minute / 60), minute % 60), zone); }
    static weekday(time, zone = AppTime.zone) { return AppTime.civil(time, zone).getUTCDay(); }
    static dateKey(time, zone = AppTime.zone) { const c = AppTime.civil(time, zone); return `${c.getUTCFullYear()}-${String(c.getUTCMonth() + 1).padStart(2, '0')}-${String(c.getUTCDate()).padStart(2, '0')}`; }
    static clock(time, zone = AppTime.zone) { const c = AppTime.civil(time, zone); return `${String(c.getUTCHours()).padStart(2, '0')}:${String(c.getUTCMinutes()).padStart(2, '0')}`; }
    static move(time, from, to) { return AppTime.fromCivil(AppTime.civil(time, from).getTime(), to); }
}
exports.AppTime = AppTime;
AppTime.systemZone = 'system';
AppTime.zone = 'system';
AppTime.resolve = (zone, time) => {
    if (zone === 'UTC') {
        return 0;
    }
    if (zone === 'system') {
        return -new Date(time).getTimezoneOffset() * 60000;
    }
    throw new Error('时区尚未初始化');
};

},
"model/AppTheme":function(require,module,exports){
"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.themeColors = exports.ThemeColors = exports.toneLabels = exports.toneIds = void 0;
exports.toneIds = ['mono', 'whale', 'orange', 'red', 'green', 'pink', 'purple'];
exports.toneLabels = ['黑白调', '鲸鱼蓝', '暖橙', '中国红', '青葱绿', '温柔粉', '高贵紫'];
class ThemeColors {
    constructor() {
        this.paper = '';
        this.surface = '';
        this.ink = '';
        this.muted = '';
        this.accent = '';
        this.tint = '';
        this.line = '';
        this.primary = '';
        this.onPrimary = '';
        this.hero = '';
    }
}
exports.ThemeColors = ThemeColors;
function themeColors(dark, tone = 'whale') {
    const index = Math.max(0, exports.toneIds.indexOf(tone));
    const c = new ThemeColors();
    c.paper = dark ? '#171C20' : ['#F7F7F8', '#F5F7FC', '#FCF8F2', '#FCF6F5', '#F5F9F5', '#FCF6F8', '#F8F6FC'][index];
    c.surface = dark ? '#22292E' : ['#FCFCFD', '#FCFDFF', '#FFFCF8', '#FFFAF9', '#FAFDFA', '#FFFAFC', '#FDFAFF'][index];
    c.ink = dark ? '#F0F3F5' : '#26343D';
    c.muted = dark ? '#ADBCC5' : '#687A85';
    c.accent = dark ? ['#DADCE4', '#9BBCF4', '#F1C18C', '#F4AAA3', '#A2D2AC', '#EDB5CB', '#CBB6EA'][index] :
        ['#343841', '#3F65A2', '#A45E22', '#B63D3D', '#39784A', '#AC5C7D', '#79549F'][index];
    c.tint = dark ? ['#32353C', '#233F4B', '#443729', '#482E30', '#293E31', '#432F3D', '#393247'][index] :
        ['#ECEEF1', '#EAF0FC', '#FAECD9', '#F9E6E4', '#E6F1E5', '#F9E7EF', '#EFE6F7'][index];
    c.line = dark ? '#36434A' : ['#E3E5E9', '#DDE5F5', '#F0E3D2', '#F0DDDA', '#DDE9DC', '#EEDDE5', '#E5DCED'][index];
    c.hero = ['#343841', '#344F79', '#9D5C29', '#A93D3D', '#376D47', '#98526E', '#6B4B8E'][index];
    c.primary = dark ? c.accent : c.hero;
    c.onPrimary = dark ? '#1B2830' : '#FFFFFF';
    return c;
}
exports.themeColors = themeColors;

},
"model/MobileModel":function(require,module,exports){
"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.monthCells = exports.taskStats = exports.TaskStats = exports.nextRepeat = exports.restoreTask = exports.deleteTask = exports.trashTasks = exports.allDayEvent = exports.allDaySpan = exports.activeTasks = exports.tasksOn = exports.finishTask = exports.arrange = exports.upsertTask = exports.undoPlan = exports.acceptPlan = exports.proposePlan = exports.PlanProposal = exports.checkData = exports.workHoursOn = exports.workHoursFor = exports.validZone = exports.parseClock = exports.parseTime = exports.localText = exports.minuteText = exports.clock = exports.clone = exports.ArrangeResult = exports.MobileData = exports.WorkDate = exports.WorkHours = exports.Diary = exports.MobileTask = exports.dateKey = exports.uid = exports.addDays = exports.dayStart = exports.MINUTE = exports.Block = void 0;
const Types_1 = require("../engine/Types");
Object.defineProperty(exports, "Block", { enumerable: true, get: function () { return Types_1.Block; } });
Object.defineProperty(exports, "MINUTE", { enumerable: true, get: function () { return Types_1.MINUTE; } });
Object.defineProperty(exports, "dayStart", { enumerable: true, get: function () { return Types_1.dayStart; } });
Object.defineProperty(exports, "addDays", { enumerable: true, get: function () { return Types_1.addDays; } });
Object.defineProperty(exports, "uid", { enumerable: true, get: function () { return Types_1.uid; } });
Object.defineProperty(exports, "dateKey", { enumerable: true, get: function () { return Types_1.dateKey; } });
const Scheduler_1 = require("../engine/Scheduler");
const AppTime_1 = require("./AppTime");
class MobileTask {
    constructor() {
        this.id = '';
        this.title = '';
        this.note = '';
        this.category = '生活';
        this.minutes = 0;
        this.deadline = 0;
        this.priority = 3;
        this.done = false;
        this.createdAt = 0;
        this.completedAt = 0;
        this.rating = 0;
        this.repeat = 'none';
        this.deletedAt = 0;
        this.repeatSource = '';
    }
}
exports.MobileTask = MobileTask;
class Diary {
    constructor() {
        this.day = '';
        this.text = '';
    }
}
exports.Diary = Diary;
class WorkHours {
    constructor(start, end) { this.start = start; this.end = end; }
}
exports.WorkHours = WorkHours;
class WorkDate {
    constructor() {
        this.day = '';
        this.start = 540;
        this.end = 1320;
    }
}
exports.WorkDate = WorkDate;
class MobileData {
    constructor() {
        this.version = 1;
        this.tasks = [];
        this.blocks = [];
        this.diaries = [];
        this.revision = 0;
        this.workStart = 540;
        this.workEnd = 1320;
        this.theme = 'light';
    }
}
exports.MobileData = MobileData;
class ArrangeResult {
    constructor() {
        this.data = new MobileData();
        this.missing = 0;
        this.skipped = 0;
    }
}
exports.ArrangeResult = ArrangeResult;
function clone(value) { return JSON.parse(JSON.stringify(value)); }
exports.clone = clone;
function clock(time) { return AppTime_1.AppTime.clock(time); }
exports.clock = clock;
function minuteText(value) { return `${String(Math.floor(value / 60)).padStart(2, '0')}:${String(value % 60).padStart(2, '0')}`; }
exports.minuteText = minuteText;
function localText(value) { return value > 0 ? `${(0, Types_1.dateKey)(value)} ${clock(value)}` : ''; }
exports.localText = localText;
function parseTime(value) {
    if (!/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$/.test(value)) {
        return NaN;
    }
    let time;
    try {
        time = AppTime_1.AppTime.fromCivil(Date.parse(value.replace(' ', 'T') + 'Z'));
    }
    catch {
        return NaN;
    }
    return Number.isFinite(time) && localText(time) === value ? time : NaN;
}
exports.parseTime = parseTime;
function parseClock(value) { if (!/^\d{2}:\d{2}$/.test(value)) {
    return NaN;
} const p = value.split(':'); const h = Number(p[0]), m = Number(p[1]); return h < 24 && m < 60 ? h * 60 + m : NaN; }
exports.parseClock = parseClock;
function validWorkHours(start, end) {
    return Number.isInteger(start) && Number.isInteger(end) && start >= 0 && end <= 1440 && start < end;
}
function validZone(zone) { return typeof zone === 'string' && zone.length <= 80 && /^[A-Za-z0-9_+\-]+(?:\/[A-Za-z0-9_+\-]+){0,2}$/.test(zone); }
exports.validZone = validZone;
function workHoursFor(data, weekday) {
    const windows = data.workWindows;
    if (windows?.length === 7) {
        return windows[weekday];
    }
    if (windows?.length === 2) {
        return windows[weekday === 0 || weekday === 6 ? 1 : 0];
    }
    return new WorkHours(data.workStart, data.workEnd);
}
exports.workHoursFor = workHoursFor;
function workHoursOn(data, time) {
    const override = data.workDates?.find((entry) => entry.day === (0, Types_1.dateKey)(time));
    return override ? new WorkHours(override.start, override.end) : workHoursFor(data, AppTime_1.AppTime.weekday(time));
}
exports.workHoursOn = workHoursOn;
function checkData(data) {
    if (data === null || typeof data !== 'object' || data.version !== 1 || !Array.isArray(data.tasks) || !Array.isArray(data.blocks) || !Array.isArray(data.diaries)) {
        throw new Error('本机记录格式无效，原文件已保留');
    }
    if (data.revision === undefined) {
        data.revision = 0;
    }
    if (!Number.isSafeInteger(data.revision) || data.revision < 0 || !validWorkHours(data.workStart, data.workEnd) || !['light', 'dark', 'system'].includes(data.theme)) {
        throw new Error('偏好设置无效，原文件已保留');
    }
    if (data.workWindows !== undefined && (!Array.isArray(data.workWindows) || ![2, 7].includes(data.workWindows.length) ||
        data.workWindows.some((hours) => !hours || !validWorkHours(hours.start, hours.end)))) {
        throw new Error('行动时间设置无效');
    }
    if (data.workDates !== undefined && (!Array.isArray(data.workDates) || data.workDates.length > 512 ||
        data.workDates.some((entry, index) => !entry || typeof entry.day !== 'string' ||
            !/^\d{4}-\d{2}-\d{2}$/.test(entry.day) || new Date(entry.day + 'T12:00:00Z').toISOString().slice(0, 10) !== entry.day ||
            !validWorkHours(entry.start, entry.end) || data.workDates.findIndex((other) => other.day === entry.day) !== index))) {
        throw new Error('单日行动时间无效');
    }
    if ((data.tone !== undefined && !['mono', 'whale', 'orange', 'red', 'green', 'pink', 'purple'].includes(data.tone)) ||
        (data.corners !== undefined && !['round', 'square'].includes(data.corners)) ||
        (data.avatar !== undefined && (typeof data.avatar !== 'string' || !/^whaletodo-avatar-(guest|[a-f0-9-]{36})-\d+\.jpg$/.test(data.avatar)))) {
        throw new Error('外观设置无效');
    }
    if ((data.nickname !== undefined && (typeof data.nickname !== 'string' || data.nickname.length > 40)) ||
        (data.motto !== undefined && (typeof data.motto !== 'string' || data.motto.length > 160)) ||
        (data.timeZone !== undefined && !validZone(data.timeZone)) ||
        (data.zonePolicy !== undefined && !['absolute', 'relative'].includes(data.zonePolicy))) {
        throw new Error('个人资料或时区设置无效');
    }
    if (data.tasks.some((task) => task.timeZone !== undefined && !validZone(task.timeZone)) ||
        data.blocks.some((block) => block.timeZone !== undefined && !validZone(block.timeZone)) ||
        data.diaries.some((diary) => diary.timeZone !== undefined && !validZone(diary.timeZone))) {
        throw new Error('记录时区无效');
    }
    const ids = [];
    for (const t of data.tasks) {
        if (t.repeat === undefined) {
            t.repeat = 'none';
        }
        if (t.deletedAt === undefined) {
            t.deletedAt = 0;
        }
        if (t.repeatSource === undefined) {
            t.repeatSource = '';
        }
        if (!['none', 'daily', 'weekdays', 'weekly'].includes(t.repeat) || !Number.isFinite(t.deletedAt) || t.deletedAt < 0 || typeof t.repeatSource !== 'string' || t.repeatSource.length > 120) {
            throw new Error('重复或回收记录无效，原文件已保留');
        }
        if (!t || typeof t.id !== 'string' || t.id === '' || ids.includes(t.id) || typeof t.title !== 'string' || !t.title.trim() || t.title.length > 120 || typeof t.note !== 'string' || t.note.length > 2000 || typeof t.category !== 'string' || !Number.isInteger(t.minutes) || t.minutes < 0 || t.minutes > 525600 || !Number.isFinite(t.deadline) || t.deadline < 0 || !Number.isFinite(t.createdAt) || !Number.isFinite(t.completedAt) || typeof t.done !== 'boolean' || !Number.isFinite(t.priority) || t.priority < 1 || t.priority > 5 || !Number.isInteger(t.rating) || t.rating < 0 || t.rating > 5) {
            throw new Error('事项记录无效，原文件已保留');
        }
        ids.push(t.id);
    }
    const blocks = [];
    for (const b of data.blocks) {
        if (!b || typeof b.id !== 'string' || blocks.includes(b.id) || !ids.includes(b.taskId) || !Number.isFinite(b.start) || !Number.isFinite(b.end) || b.start >= b.end || typeof b.locked !== 'boolean' || typeof b.done !== 'boolean') {
            throw new Error('时间安排无效，原文件已保留');
        }
        blocks.push(b.id);
    }
    for (const d of data.diaries) {
        if (!d || typeof d.day !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(d.day) || typeof d.text !== 'string' || d.text.length > 800) {
            throw new Error('日记记录无效，原文件已保留');
        }
    }
    return data;
}
exports.checkData = checkData;
class PlanProposal {
    constructor() {
        this.id = '';
        this.baseSignature = '';
        this.before = [];
        this.after = [];
        this.missing = 0;
        this.skipped = 0;
        this.added = 0;
        this.moved = 0;
        this.preserved = 0;
    }
}
exports.PlanProposal = PlanProposal;
function proposePlan(data, now = Date.now()) {
    const planned = arrange(data, now), p = new PlanProposal();
    p.id = (0, Types_1.uid)('proposal');
    p.baseSignature = JSON.stringify(data);
    p.before = clone(data).blocks;
    p.after = planned.data.blocks;
    p.missing = planned.missing;
    p.skipped = planned.skipped;
    p.preserved = p.after.filter((b) => data.blocks.some((old) => old.id === b.id && old.start === b.start && old.end === b.end)).length;
    p.added = p.after.length - p.preserved;
    p.moved = data.blocks.filter((old) => !p.after.some((b) => b.id === old.id && b.start === old.start && b.end === old.end)).length;
    return p;
}
exports.proposePlan = proposePlan;
function acceptPlan(data, proposal, now = Date.now()) {
    if (JSON.stringify(data) !== proposal.baseSignature) {
        throw new Error('事项已变化，请重新生成计划提案');
    }
    if (proposal.after.some((b) => !proposal.before.some((old) => old.id === b.id) && b.start < now)) {
        throw new Error('提案的开始时间已过，请重新生成');
    }
    const next = clone(data);
    next.blocks = proposal.after.map((b) => JSON.parse(JSON.stringify(b)));
    return checkData(next);
}
exports.acceptPlan = acceptPlan;
function undoPlan(data, before, appliedSignature) {
    if (JSON.stringify(data) !== appliedSignature) {
        throw new Error('计划之后已有其它修改，不能直接撤销，请重新安排');
    }
    const next = clone(data);
    next.blocks = before.map((b) => JSON.parse(JSON.stringify(b)));
    return checkData(next);
}
exports.undoPlan = undoPlan;
function upsertTask(data, task, reservation = 0, now = Date.now()) {
    if (!task.title.trim()) {
        throw new Error('先写下想做的事');
    }
    if (task.minutes !== 0 && task.minutes < 15) {
        throw new Error('预计用时至少15分钟，也可以留空稍后整理');
    }
    const next = clone(data);
    const index = next.tasks.findIndex((t) => t.id === task.id);
    task.title = task.title.trim();
    if (index >= 0) {
        next.tasks[index] = task;
    }
    else {
        next.tasks.push(task);
    }
    const protectedBlocks = next.blocks.filter((b) => b.taskId === task.id && (b.locked || b.done || b.start < now));
    if (task.deadline > 0 && protectedBlocks.some((b) => b.end > task.deadline)) {
        throw new Error('截止时间早于已保留的安排，请先调整安排');
    }
    if (reservation > 0) {
        const end = reservation + task.minutes * Types_1.MINUTE;
        if (task.done || task.minutes < 15 || reservation < now || task.deadline <= 0 || end > task.deadline) {
            throw new Error('预约须在未来，填写用时和截止时间，并在截止前结束');
        }
        const date = AppTime_1.AppTime.view(reservation), hours = workHoursOn(data, reservation);
        const minute = date.getHours() * 60 + date.getMinutes();
        if ((0, Types_1.dayStart)(reservation) !== (0, Types_1.dayStart)(end - 1) || minute < hours.start || minute + task.minutes > hours.end) {
            throw new Error('预约须在当天的行动时间内');
        }
        if (next.blocks.some((b) => b.taskId !== task.id && (0, Scheduler_1.overlap)({ start: b.start, end: b.end }, { start: reservation, end: end }))) {
            throw new Error('这个时段已有安排，请选择其它时间');
        }
        if (protectedBlocks.some((b) => b.done || b.start < now)) {
            throw new Error('事项已有执行记录，暂不能覆盖预约');
        }
        next.blocks = next.blocks.filter((b) => b.taskId !== task.id);
        const block = new Types_1.Block();
        block.id = (0, Types_1.uid)('manual');
        block.taskId = task.id;
        block.start = reservation;
        block.end = end;
        block.locked = true;
        next.blocks.push(block);
    }
    else if (index >= 0) {
        next.blocks = next.blocks.filter((b) => b.taskId !== task.id || b.locked || b.done || b.start < now);
    }
    return checkData(next);
}
exports.upsertTask = upsertTask;
function arrange(data, now = Date.now()) {
    const engine = new Types_1.AppData();
    engine.settings.horizonDays = 366;
    engine.settings.termStart = (0, Types_1.dayStart)(now);
    for (let i = 0; i < engine.settings.horizonDays; i++) {
        const day = (0, Types_1.addDays)(engine.settings.termStart, i), hours = workHoursOn(data, day), f = new Types_1.FreeWindow();
        f.id = `day-${(0, Types_1.dateKey)(day)}`;
        f.date = (0, Types_1.dateKey)(day);
        f.startMinute = hours.start;
        f.endMinute = hours.end;
        engine.free.push(f);
    }
    let skipped = 0;
    for (const m of activeTasks(data)) {
        if (m.minutes === 0 || m.deadline === 0) {
            if (!m.done) {
                skipped++;
            }
            continue;
        }
        const t = new Types_1.Task();
        t.id = m.id;
        t.title = m.title;
        t.note = m.note;
        t.minutes = m.minutes;
        t.deadline = m.deadline;
        t.priority = m.priority;
        t.archived = m.done;
        t.chunk = Math.min(45, m.minutes);
        t.createdAt = m.createdAt;
        engine.tasks.push(t);
    }
    engine.blocks = data.blocks.filter((b) => data.tasks.some((t) => t.id === b.taskId && !t.deletedAt)).map((b) => JSON.parse(JSON.stringify(b)));
    const planned = (0, Scheduler_1.schedule)(engine, now);
    const result = new ArrangeResult();
    result.data = clone(data);
    result.data.blocks = planned.blocks;
    result.missing = planned.unmet.reduce((sum, u) => sum + u.minutes, 0);
    result.skipped = skipped;
    checkData(result.data);
    return result;
}
exports.arrange = arrange;
function finishTask(data, id, rating, now = Date.now()) {
    if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
        throw new Error('请选择1—5星自评');
    }
    const next = clone(data);
    const task = next.tasks.find((t) => t.id === id && !t.deletedAt);
    if (task === undefined) {
        throw new Error('事项不存在');
    }
    if (task.done) {
        task.done = false;
        task.completedAt = 0;
        task.rating = 0;
        next.blocks = next.blocks.filter((b) => b.taskId !== id || !b.done);
    }
    else {
        task.done = true;
        task.completedAt = now;
        task.rating = rating;
        next.blocks = next.blocks.filter((b) => b.taskId !== id || b.start < now);
        for (const b of next.blocks.filter((b) => b.taskId === id)) {
            b.done = true;
            b.completedAt = now;
            b.rating = rating;
        }
        if (task.repeat && task.repeat !== 'none' && !next.tasks.some((t) => t.repeatSource === id)) {
            const upcoming = JSON.parse(JSON.stringify(task));
            upcoming.id = (0, Types_1.uid)('repeat');
            upcoming.repeatSource = id;
            upcoming.done = false;
            upcoming.completedAt = 0;
            upcoming.rating = 0;
            upcoming.createdAt = now;
            upcoming.deadline = nextRepeat(task.deadline || now, task.repeat, now);
            next.tasks.push(upcoming);
        }
    }
    return checkData(next);
}
exports.finishTask = finishTask;
function tasksOn(data, day) {
    const end = (0, Types_1.addDays)((0, Types_1.dayStart)(day), 1), start = (0, Types_1.dayStart)(day);
    return activeTasks(data).filter((t) => { const span = allDaySpan(t); if (span.length === 2) {
        const key = (0, Types_1.dateKey)(start);
        return key >= span[0] && key <= span[1];
    } const deadline = t.category === '日历' && t.note.startsWith('全天日程：') && t.deadline > 0 ? t.deadline - 1 : t.deadline; return (deadline >= start && deadline < end) || (t.done && t.completedAt >= start && t.completedAt < end) || data.blocks.some((b) => b.taskId === t.id && b.start < end && b.end > start); });
}
exports.tasksOn = tasksOn;
function activeTasks(data) { return data.tasks.filter((t) => !t.deletedAt); }
exports.activeTasks = activeTasks;
function allDaySpan(task) {
    if (!task.id.startsWith('calendar-event-') || task.category !== '日历') {
        return [];
    }
    const found = /^全天日程：(\d{4}-\d{2}-\d{2})(?: — (\d{4}-\d{2}-\d{2}))?(?:\n|$)/.exec(task.note);
    if (!found) {
        return [];
    }
    const first = found[1], last = found[2] || first;
    for (const key of [first, last]) {
        const at = Date.parse(key + 'T00:00:00Z');
        if (!Number.isFinite(at) || new Date(at).toISOString().slice(0, 10) !== key) {
            return [];
        }
    }
    return first <= last ? [first, last] : [];
}
exports.allDaySpan = allDaySpan;
function allDayEvent(data, block) { const task = data.tasks.find((item) => item.id === block.taskId); return !!task && allDaySpan(task).length === 2 && block.id === `calendar-block-${task.id.slice('calendar-'.length)}`; }
exports.allDayEvent = allDayEvent;
function trashTasks(data) { return data.tasks.filter((t) => t.deletedAt > 0).sort((a, b) => b.deletedAt - a.deletedAt); }
exports.trashTasks = trashTasks;
function deleteTask(data, id, now = Date.now()) { const next = clone(data), task = next.tasks.find((t) => t.id === id && !t.deletedAt); if (!task) {
    throw new Error('事项不存在');
} task.deletedAt = now; next.blocks = next.blocks.filter((b) => b.taskId !== id); return checkData(next); }
exports.deleteTask = deleteTask;
function restoreTask(data, id) { const next = clone(data), task = next.tasks.find((t) => t.id === id && t.deletedAt > 0); if (!task) {
    throw new Error('回收事项不存在');
} task.deletedAt = 0; return checkData(next); }
exports.restoreTask = restoreTask;
function nextRepeat(deadline, repeat, now) {
    if (!['daily', 'weekdays', 'weekly'].includes(repeat)) {
        throw new Error('重复规则无效');
    }
    const step = repeat === 'weekly' ? 7 : 1;
    let at = (0, Types_1.addDays)(deadline, step);
    if (at <= now) {
        const elapsed = Math.floor(((0, Types_1.dayStart)(now) - (0, Types_1.dayStart)(at)) / (24 * 60 * Types_1.MINUTE));
        at = (0, Types_1.addDays)(at, Math.max(0, Math.floor(elapsed / step)) * step);
        while (at <= now) {
            at = (0, Types_1.addDays)(at, step);
        }
    }
    if (repeat === 'weekdays') {
        while (AppTime_1.AppTime.weekday(at) === 0 || AppTime_1.AppTime.weekday(at) === 6) {
            at = (0, Types_1.addDays)(at, 1);
        }
    }
    return at;
}
exports.nextRepeat = nextRepeat;
class TaskStats {
    constructor() {
        this.total = 0;
        this.pending = 0;
        this.completed = 0;
        this.overdue = 0;
        this.completedWeek = 0;
        this.plannedMinutes = 0;
        this.completedMinutes = 0;
    }
}
exports.TaskStats = TaskStats;
function taskStats(data, now = Date.now()) { const s = new TaskStats(), tasks = activeTasks(data), week = (0, Types_1.addDays)((0, Types_1.dayStart)(now), -6); s.total = tasks.length; s.pending = tasks.filter((t) => !t.done).length; s.completed = tasks.filter((t) => t.done).length; s.overdue = tasks.filter((t) => !t.done && t.deadline > 0 && t.deadline < now).length; s.completedWeek = tasks.filter((t) => t.done && t.completedAt >= week && t.completedAt <= now).length; s.plannedMinutes = data.blocks.filter((b) => !b.done && tasks.some((t) => t.id === b.taskId && !t.done)).reduce((sum, b) => sum + (b.end - b.start) / Types_1.MINUTE, 0); s.completedMinutes = tasks.filter((t) => t.done).reduce((sum, t) => sum + t.minutes, 0); return s; }
exports.taskStats = taskStats;
function monthCells(month) {
    const d = AppTime_1.AppTime.view(month);
    d.setDate(1);
    const first = AppTime_1.AppTime.fromView(d);
    const start = (0, Types_1.addDays)(first, -((d.getDay() + 6) % 7));
    const days = [];
    for (let i = 0; i < 42; i++) {
        days.push((0, Types_1.addDays)(start, i));
    }
    return days;
}
exports.monthCells = monthCells;

},
"model/SyncPlan":function(require,module,exports){
"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.buildSyncPlan = exports.checkScope = exports.serverSnapshot = exports.SyncPlan = exports.SyncScope = void 0;
const MobileModel_1 = require("./MobileModel");
class SyncScope {
    constructor() {
        this.schedule = true;
        this.diaries = false;
    }
}
exports.SyncScope = SyncScope;
class SyncPlan {
    constructor() {
        this.candidate = new MobileModel_1.MobileData();
        this.skippedBlocks = 0;
        this.addedTasks = 0;
        this.addedDiaries = 0;
    }
}
exports.SyncPlan = SyncPlan;
function serverSnapshot(data) {
    const next = (0, MobileModel_1.clone)(data);
    next.workWindows = undefined;
    next.workDates = undefined;
    next.tone = undefined;
    next.corners = undefined;
    next.avatar = undefined;
    next.nickname = undefined;
    next.motto = undefined;
    next.zonePolicy = undefined;
    return (0, MobileModel_1.checkData)(next);
}
exports.serverSnapshot = serverSnapshot;
function checkScope(scope) { if (typeof scope.schedule !== 'boolean' || typeof scope.diaries !== 'boolean' || (!scope.schedule && !scope.diaries)) {
    throw new Error('请至少选择日程或日记');
} }
exports.checkScope = checkScope;
function buildSyncPlan(local, remote, kind, scope) {
    checkScope(scope);
    (0, MobileModel_1.checkData)(local);
    (0, MobileModel_1.checkData)(remote);
    if (!['push', 'pull', 'merge'].includes(kind)) {
        throw new Error('同步方式无效');
    }
    const plan = new SyncPlan();
    if (kind === 'push') {
        const next = (0, MobileModel_1.clone)(remote), source = (0, MobileModel_1.clone)(local);
        if (scope.schedule) {
            next.tasks = source.tasks;
            next.blocks = source.blocks;
            next.workStart = source.workStart;
            next.workEnd = source.workEnd;
            next.timeZone = source.timeZone;
        }
        if (scope.diaries) {
            next.diaries = source.diaries;
        }
        next.theme = 'light';
        next.revision = source.revision;
        plan.candidate = serverSnapshot(next);
        return plan;
    }
    const next = (0, MobileModel_1.clone)(local), source = (0, MobileModel_1.clone)(remote);
    next.theme = local.theme;
    if (kind === 'pull') {
        if (scope.schedule) {
            next.tasks = source.tasks;
            next.blocks = source.blocks;
            next.workStart = source.workStart;
            next.workEnd = source.workEnd;
        }
        if (scope.diaries) {
            next.diaries = source.diaries;
        }
    }
    else {
        if (scope.schedule) {
            const localIds = next.tasks.map((t) => t.id), added = [];
            for (const task of source.tasks) {
                if (localIds.includes(task.id)) {
                    continue;
                }
                next.tasks.push(task);
                added.push(task.id);
                plan.addedTasks++;
            }
            for (const block of source.blocks.sort((a, b) => a.start - b.start || a.id.localeCompare(b.id))) {
                if (!added.includes(block.taskId) || next.tasks.some((t) => t.id === block.taskId && t.deletedAt > 0)) {
                    continue;
                }
                if (next.blocks.some((b) => b.id === block.id || (block.start < b.end && b.start < block.end))) {
                    plan.skippedBlocks++;
                    continue;
                }
                next.blocks.push(block);
            }
        }
        if (scope.diaries) {
            for (const diary of source.diaries) {
                if (next.diaries.some((d) => d.day === diary.day)) {
                    continue;
                }
                next.diaries.push(diary);
                plan.addedDiaries++;
            }
        }
    }
    if (next.tasks.length > 10000 || next.blocks.length > 50000 || next.diaries.length > 10000) {
        throw new Error('合并记录超过当前存储能力，请缩小范围或整理后重试');
    }
    plan.candidate = (0, MobileModel_1.checkData)(next);
    return plan;
}
exports.buildSyncPlan = buildSyncPlan;

},
"model/AssistantPlan":function(require,module,exports){
"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.applyAssistantPlan = exports.planSize = exports.AssistantPlan = exports.PlannedTime = exports.TaskEdit = exports.AiTask = void 0;
const MobileModel_1 = require("./MobileModel");
const AppTime_1 = require("./AppTime");
class AiTask {
    constructor() {
        this.title = '';
        this.note = '';
        this.category = '生活';
        this.minutes = 0;
        this.deadline = 0;
        this.priority = 3;
    }
}
exports.AiTask = AiTask;
class TaskEdit extends AiTask {
    constructor() {
        super(...arguments);
        this.taskId = '';
    }
}
exports.TaskEdit = TaskEdit;
class PlannedTime {
    constructor() {
        this.taskId = '';
        this.start = 0;
        this.end = 0;
    }
}
exports.PlannedTime = PlannedTime;
class AssistantPlan {
    constructor() {
        this.tasks = [];
    }
}
exports.AssistantPlan = AssistantPlan;
function planSize(plan) { return plan.tasks.length + (plan.edits?.length || 0) + (plan.schedule?.length || 0); }
exports.planSize = planSize;
/** Pure preview/application. No writes; callers compare the base signature and ask for consent. */
function applyAssistantPlan(data, plan, now = Date.now()) {
    let next = (0, MobileModel_1.clone)(data);
    const edits = plan.edits || [], times = plan.schedule || [], edited = [], scheduled = [], newIds = [];
    for (const item of edits) {
        const old = next.tasks.find((task) => task.id === item.taskId);
        if (!old || old.done || old.deletedAt || old.id.startsWith('calendar-') || edited.includes(item.taskId)) {
            throw new Error('提案包含不可编辑的事项，请重新生成');
        }
        if (item.minutes !== 0 && item.minutes < 15) {
            throw new Error('预计用时至少15分钟，也可以留空');
        }
        if (item.deadline > 0 && next.blocks.some((block) => block.taskId === item.taskId && block.end > item.deadline)) {
            throw new Error('新截止时间早于已有安排，请先调整安排');
        }
        edited.push(item.taskId);
        const task = cloneTask(old);
        task.title = item.title.trim();
        task.note = item.note;
        task.category = item.category;
        task.minutes = item.minutes;
        task.deadline = item.deadline;
        task.priority = item.priority;
        task.timeZone = AppTime_1.AppTime.zone;
        next.tasks[next.tasks.findIndex((entry) => entry.id === item.taskId)] = task;
    }
    for (const item of plan.tasks) {
        const task = new MobileModel_1.MobileTask();
        task.id = (0, MobileModel_1.uid)('ai_task');
        task.title = item.title;
        task.note = item.note;
        task.category = item.category;
        task.minutes = item.minutes;
        task.deadline = item.deadline;
        task.priority = item.priority;
        task.createdAt = now;
        task.timeZone = AppTime_1.AppTime.zone;
        next = (0, MobileModel_1.upsertTask)(next, task);
        newIds.push(task.id);
    }
    for (const item of times) {
        const target = /^new:\d+$/.test(item.taskId) ? newIds[Number(item.taskId.slice(4))] || '' : item.taskId;
        const task = next.tasks.find((task) => task.id === target);
        if (!task || task.done || task.deletedAt || task.id.startsWith('calendar-') || scheduled.includes(target) || !Number.isSafeInteger(item.start) || !Number.isSafeInteger(item.end) || item.start < now || item.end <= item.start || item.end - item.start > 1440 * 60000 || task.deadline > 0 && item.end > task.deadline) {
            throw new Error('建议时段无效，或超出事项截止时间');
        }
        if (task.minutes > 0 && item.end - item.start !== task.minutes * 60000) {
            throw new Error('建议时段与预计用时不一致，请先调整提案');
        }
        if (next.blocks.some((block) => block.taskId === target && (block.locked || block.done || block.start < now))) {
            throw new Error('该事项已有固定或历史安排，请手动调整');
        }
        const hours = (0, MobileModel_1.workHoursOn)(next, item.start), startClock = AppTime_1.AppTime.view(item.start), endClock = AppTime_1.AppTime.view(item.end - 1);
        if ((0, MobileModel_1.dayStart)(item.start) !== (0, MobileModel_1.dayStart)(item.end - 1) || startClock.getHours() * 60 + startClock.getMinutes() < hours.start || endClock.getHours() * 60 + endClock.getMinutes() >= hours.end) {
            throw new Error('建议时段须在当天的行动时间内');
        }
        scheduled.push(target);
        next.blocks = next.blocks.filter((block) => block.taskId !== target);
        if (next.blocks.some((block) => item.start < block.end && block.start < item.end)) {
            throw new Error('建议时段与已有安排冲突，请先调整提案');
        }
        const block = new MobileModel_1.Block();
        block.id = (0, MobileModel_1.uid)('ai_block');
        block.taskId = target;
        block.start = item.start;
        block.end = item.end;
        block.timeZone = AppTime_1.AppTime.zone;
        next.blocks.push(block);
    }
    return (0, MobileModel_1.checkData)(next);
}
exports.applyAssistantPlan = applyAssistantPlan;
function cloneTask(task) { return JSON.parse(JSON.stringify(task)); }

},
"model/CalendarImport":function(require,module,exports){
"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.calendarImport = exports.calendarRecord = exports.CalendarImportRecord = void 0;
const MobileModel_1 = require("./MobileModel");
const AppTime_1 = require("./AppTime");
class CalendarImportRecord {
    constructor() {
        this.id = '';
        this.title = '';
        this.start = 0;
        this.end = 0;
        this.location = '';
        this.allDay = false;
    }
}
exports.CalendarImportRecord = CalendarImportRecord;
function calendarRecord(eventId, title, start, end, allDay, location = '') {
    if (!Number.isSafeInteger(eventId) || eventId < 0 || !Number.isSafeInteger(start) || !Number.isSafeInteger(end) || end <= start) {
        throw new Error('系统日程时间无效，未导入任何事项');
    }
    const record = new CalendarImportRecord();
    record.id = `event-${eventId}-${start}-${end}`;
    record.title = title || '未命名日程';
    record.location = location;
    record.start = start;
    record.end = end;
    record.allDay = allDay;
    if (allDay) {
        const first = new Date(start), last = new Date(end), utcMidnights = first.getUTCHours() === 0 && first.getUTCMinutes() === 0 && first.getUTCSeconds() === 0 && last.getUTCHours() === 0 && last.getUTCMinutes() === 0 && last.getUTCSeconds() === 0;
        // Calendar providers commonly encode date-only holidays at UTC midnight. Preserve their calendar date, not their UTC+8 clock time.
        record.start = utcMidnights ? AppTime_1.AppTime.fromCivil(Date.UTC(first.getUTCFullYear(), first.getUTCMonth(), first.getUTCDate())) : (0, MobileModel_1.dayStart)(start);
        record.end = utcMidnights ? AppTime_1.AppTime.fromCivil(Date.UTC(last.getUTCFullYear(), last.getUTCMonth(), last.getUTCDate())) : (0, MobileModel_1.dayStart)(end);
        if (record.end <= record.start) {
            throw new Error('全天日程日期无效，未导入任何事项');
        }
    }
    return record;
}
exports.calendarRecord = calendarRecord;
function calendarImport(data, records, signature, now = Date.now()) {
    if (JSON.stringify(data) !== signature) {
        throw new Error('事项已变化，请重新预览系统日历');
    }
    if (records.length === 0) {
        throw new Error('请先选择要导入的日程');
    }
    const next = (0, MobileModel_1.clone)(data);
    let added = 0;
    for (const record of records) {
        if (!record.id || record.id.length > 100 || !record.title.trim() || record.title.length > 120 || !Number.isSafeInteger(record.start) || !Number.isSafeInteger(record.end) || record.start < 0 || record.end <= record.start || record.end <= now || Math.ceil((record.end - record.start) / MobileModel_1.MINUTE) > 525600 || record.location.length > 1900) {
            throw new Error('日程内容或时间无效，请重新选择');
        }
        const id = `calendar-${record.id}`;
        if (next.tasks.some((t) => t.id === id)) {
            continue;
        }
        if (next.blocks.some((b) => record.start < b.end && b.start < record.end)) {
            throw new Error(`“${record.title}”与已有或所选安排重叠，请取消冲突项后重试`);
        }
        const task = new MobileModel_1.MobileTask();
        task.id = id;
        task.title = record.title.trim();
        task.category = '日历';
        task.note = (record.allDay ? `全天日程：${(0, MobileModel_1.dateKey)(record.start)}${(0, MobileModel_1.dateKey)(record.start) !== (0, MobileModel_1.dateKey)(record.end - 1) ? ` — ${(0, MobileModel_1.dateKey)(record.end - 1)}` : ''}` : '') + (record.location ? `${record.allDay ? '\n' : ''}地点：${record.location}` : '');
        task.minutes = Math.ceil((record.end - record.start) / MobileModel_1.MINUTE);
        task.deadline = record.end;
        task.createdAt = now;
        next.tasks.push(task);
        const block = new MobileModel_1.Block();
        block.id = `calendar-block-${record.id}`;
        block.taskId = id;
        block.start = record.start;
        block.end = record.end;
        block.locked = true;
        next.blocks.push(block);
        added++;
    }
    if (added === 0) {
        throw new Error('所选日程已导入，未重复添加；已删除的日程可在回收站恢复');
    }
    return (0, MobileModel_1.checkData)(next);
}
exports.calendarImport = calendarImport;

},
"model/SharingModel":function(require,module,exports){
"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.taskText = exports.tasksIcs = exports.foldIcs = void 0;
const MobileModel_1 = require("./MobileModel");
function escapeIcs(value) { return value.replace(/\\/g, '\\\\').replace(/\r\n|\r|\n/g, '\\n').replace(/;/g, '\\;').replace(/,/g, '\\,'); }
function utc(value) { return new Date(value).toISOString().replace(/[-:]/g, '').replace(/\.\d{3}Z$/, 'Z'); }
class AllDayDates {
    constructor() {
        this.start = '';
        this.last = '';
        this.end = '';
    }
}
function validDate(value) {
    const time = Date.parse(`${value}T00:00:00Z`);
    return Number.isFinite(time) && value.slice(0, 4) !== '0000' && new Date(time).toISOString().slice(0, 10) === value;
}
function allDayDates(task) {
    if (!task.id.startsWith('calendar-event-') || task.category !== '日历') {
        return undefined;
    }
    const match = /^全天日程：(\d{4}-\d{2}-\d{2})(?: — (\d{4}-\d{2}-\d{2}))?(?:\n|$)/.exec(task.note);
    if (!match) {
        return undefined;
    }
    const first = match[1], last = match[2] || first;
    if (!validDate(first) || !validDate(last) || last < first || last === '9999-12-31') {
        return undefined;
    }
    // The import note retains the original date-only span. Re-deriving dates from
    // block instants after a device timezone change would shift an all-day event.
    const dates = new AllDayDates();
    dates.start = first.replace(/-/g, '');
    dates.last = last.replace(/-/g, '');
    dates.end = new Date(Date.parse(`${last}T00:00:00Z`) + 86400000).toISOString().slice(0, 10).replace(/-/g, '');
    return dates;
}
function foldIcs(value) {
    let result = '', line = '', bytes = 0;
    for (let i = 0; i < value.length; i++) {
        let c = value.charAt(i), code = value.charCodeAt(i), size = code < 128 ? 1 : code < 2048 ? 2 : 3;
        if (code >= 0xD800 && code <= 0xDBFF && i + 1 < value.length) {
            c += value.charAt(++i);
            size = 4;
        }
        if (bytes + size > 75) {
            result += `${line}\r\n`;
            line = ' ';
            bytes = 1;
        }
        line += c;
        bytes += size;
    }
    return result + line;
}
exports.foldIcs = foldIcs;
function tasksIcs(data, taskId = '', now = Date.now()) {
    const tasks = (0, MobileModel_1.activeTasks)(data).filter((t) => !taskId || t.id === taskId);
    if (tasks.length === 0) {
        throw new Error('没有可导出的事项');
    }
    const lines = ['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//WhaleDo//Harmony Course//ZH', 'CALSCALE:GREGORIAN'];
    for (const task of tasks) {
        const blocks = data.blocks.filter((b) => b.taskId === task.id), dates = allDayDates(task);
        if (blocks.length > 0) {
            for (const b of blocks) {
                const allDay = dates !== undefined && b.id === `calendar-block-${task.id.slice('calendar-'.length)}`;
                lines.push('BEGIN:VEVENT', `UID:${encodeURIComponent(b.id)}@whaletodo.mobile`, `DTSTAMP:${utc(now)}`);
                if (allDay && dates) {
                    lines.push(`DTSTART;VALUE=DATE:${dates.start}`, `DTEND;VALUE=DATE:${dates.end}`);
                }
                else {
                    lines.push(`DTSTART:${utc(b.start)}`, `DTEND:${utc(b.end)}`);
                }
                lines.push(`SUMMARY:${escapeIcs(task.title)}`, `DESCRIPTION:${escapeIcs(task.note)}`, 'END:VEVENT');
            }
        }
        else {
            lines.push('BEGIN:VTODO', `UID:${encodeURIComponent(task.id)}@whaletodo.mobile`, `DTSTAMP:${utc(now)}`, `SUMMARY:${escapeIcs(task.title)}`, `DESCRIPTION:${escapeIcs(task.note)}`, `STATUS:${task.done ? 'COMPLETED' : 'NEEDS-ACTION'}`, `PRIORITY:${Math.max(1, 10 - Math.round(task.priority) * 2)}`);
            if (task.deadline > 0) {
                lines.push(dates ? `DUE;VALUE=DATE:${dates.last}` : `DUE:${utc(task.deadline)}`);
            }
            if (task.done && task.completedAt > 0) {
                lines.push(`COMPLETED:${utc(task.completedAt)}`);
            }
            lines.push('END:VTODO');
        }
    }
    lines.push('END:VCALENDAR');
    return lines.map((line) => foldIcs(line)).join('\r\n') + '\r\n';
}
exports.tasksIcs = tasksIcs;
function taskText(data, taskId = '') {
    const tasks = (0, MobileModel_1.activeTasks)(data).filter((t) => !taskId || t.id === taskId);
    if (tasks.length === 0) {
        throw new Error('没有可分享的事项');
    }
    return '鲸办 WhaleDo · 我的清单\n\n' + tasks.map((t) => {
        const dates = allDayDates(t), blocks = data.blocks.filter((b) => b.taskId === t.id);
        const allDay = dates !== undefined && (blocks.length === 0 || blocks.every((b) => b.id === `calendar-block-${t.id.slice('calendar-'.length)}`));
        return `${t.done ? '✓' : '□'} ${t.title}${!allDay && t.deadline ? '\n截止 ' + (0, MobileModel_1.localText)(t.deadline) : ''}${!allDay && t.minutes ? ' · 预计 ' + t.minutes + ' 分钟' : ''}${t.note ? '\n' + t.note : ''}`;
    }).join('\n\n');
}
exports.taskText = taskText;

},
"model/ReminderPlan":function(require,module,exports){
"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.reminderPlan = exports.ReminderItem = exports.ReminderOptions = void 0;
const MobileModel_1 = require("./MobileModel");
const AppTime_1 = require("./AppTime");
class ReminderOptions {
    constructor() {
        this.starts = true;
        this.deadlines = true;
        this.leadMinutes = 0;
        this.sound = 'notification';
        this.quiet = false;
        this.quietStart = 1320;
        this.quietEnd = 480;
    }
}
exports.ReminderOptions = ReminderOptions;
class ReminderItem {
    constructor() {
        this.taskId = '';
        this.title = '';
        this.at = 0;
        this.kind = '';
    }
}
exports.ReminderItem = ReminderItem;
function reminderPlan(data, now = Date.now(), options = new ReminderOptions()) {
    const result = [];
    for (const t of (0, MobileModel_1.activeTasks)(data).filter((t) => !t.done)) {
        const starts = data.blocks.filter((b) => b.taskId === t.id && !b.done && b.start > now + 1000).map((b) => b.start);
        if (options.starts) {
            for (const at of starts) {
                const item = new ReminderItem();
                item.taskId = t.id;
                item.title = t.title;
                item.at = at - options.leadMinutes * 60000;
                item.kind = options.leadMinutes ? `开始前${options.leadMinutes}分钟` : '开始';
                result.push(item);
            }
        }
        if (options.deadlines && t.deadline > now + 1000 && (!options.starts || !starts.includes(t.deadline))) {
            const item = new ReminderItem();
            item.taskId = t.id;
            item.title = t.title;
            item.at = t.deadline - options.leadMinutes * 60000;
            item.kind = options.leadMinutes ? `截止前${options.leadMinutes}分钟` : '截止';
            result.push(item);
        }
    }
    return result.filter((item) => {
        if (item.at <= now + 1000) {
            return false;
        }
        if (!options.quiet) {
            return true;
        }
        const d = AppTime_1.AppTime.civil(item.at, data.timeZone || AppTime_1.AppTime.zone), minute = d.getUTCHours() * 60 + d.getUTCMinutes();
        const quiet = options.quietStart < options.quietEnd ? minute >= options.quietStart && minute < options.quietEnd : minute >= options.quietStart || minute < options.quietEnd;
        return !quiet;
    }).sort((a, b) => a.at - b.at);
}
exports.reminderPlan = reminderPlan;

},
"model/ZonePolicy":function(require,module,exports){
"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.changeTimeZone = void 0;
const MobileModel_1 = require("./MobileModel");
const AppTime_1 = require("./AppTime");
function changeTimeZone(data, zone, policy, now = Date.now()) {
    if (!(0, MobileModel_1.validZone)(zone) || !['absolute', 'relative'].includes(policy)) {
        throw new Error('请选择时区和同步方式');
    }
    const next = (0, MobileModel_1.clone)(data), old = data.timeZone || AppTime_1.AppTime.zone;
    AppTime_1.AppTime.offset(now, zone);
    for (const task of next.tasks) {
        task.timeZone = task.timeZone || old;
    }
    for (const block of next.blocks) {
        block.timeZone = block.timeZone || old;
    }
    for (const diary of next.diaries) {
        diary.timeZone = diary.timeZone || old;
    }
    if (old !== zone) {
        for (const task of next.tasks) {
            const span = (0, MobileModel_1.allDaySpan)(task);
            if (span.length !== 2) {
                continue;
            }
            const start = AppTime_1.AppTime.fromCivil(Date.parse(span[0] + 'T00:00:00Z'), zone), end = AppTime_1.AppTime.fromCivil(Date.parse(span[1] + 'T00:00:00Z') + 86400000, zone);
            task.deadline = end;
            task.minutes = Math.round((end - start) / 60000);
            task.timeZone = zone;
            for (const block of next.blocks.filter((item) => item.taskId === task.id && (0, MobileModel_1.allDayEvent)(next, item))) {
                block.start = start;
                block.end = end;
                block.timeZone = zone;
            }
        }
    }
    if (old !== zone && policy === 'relative') {
        for (const task of next.tasks) {
            if ((0, MobileModel_1.allDaySpan)(task).length === 2) {
                continue;
            }
            if (!task.done && !task.deletedAt && task.deadline > now) {
                const shifted = AppTime_1.AppTime.move(task.deadline, old, zone);
                if (shifted <= now) {
                    throw new Error('切换会把截止时间移到过去，请先调整事项');
                }
                task.deadline = shifted;
                task.timeZone = zone;
            }
        }
        for (const block of next.blocks) {
            if ((0, MobileModel_1.allDayEvent)(next, block)) {
                continue;
            }
            if (block.done || block.start <= now) {
                continue;
            }
            const start = AppTime_1.AppTime.move(block.start, old, zone), end = AppTime_1.AppTime.move(block.end, old, zone);
            if (start <= now || end - start !== block.end - block.start) {
                throw new Error('切换会改变安排时长或移到过去，请调整安排后重试');
            }
            block.start = start;
            block.end = end;
            block.timeZone = zone;
        }
    }
    if (old !== zone) {
        for (let i = 0; i < next.blocks.length; i++) {
            const b = next.blocks[i], original = data.blocks[i];
            if (b.start === original.start && b.end === original.end) {
                continue;
            }
            const task = next.tasks.find((t) => t.id === b.taskId);
            if (task && task.deadline > 0 && b.end > task.deadline) {
                throw new Error('切换后安排超出截止时间，请先调整事项');
            }
            if (next.blocks.some((other, index) => index !== i && b.start < other.end && other.start < b.end &&
                !(original.start < data.blocks[index].end && data.blocks[index].start < original.end))) {
                throw new Error('切换会造成安排重叠，请先调整事项');
            }
        }
    }
    next.timeZone = zone;
    next.zonePolicy = policy;
    return (0, MobileModel_1.checkData)(next);
}
exports.changeTimeZone = changeTimeZone;

},
"model/AudioWav":function(require,module,exports){
"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.wavPcm = void 0;
/** PCM WAV import supported by the system recognizer: 16 kHz, mono, signed 16-bit. */
function wavPcm(bytes) {
    const bad = () => { throw new Error('请选择60秒以内、16kHz单声道16位的 WAV 音频'); };
    if (bytes.length < 44 || bytes.length > 2 * 1024 * 1024) {
        return bad();
    }
    const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    const tag = (at) => String.fromCharCode(bytes[at], bytes[at + 1], bytes[at + 2], bytes[at + 3]);
    if (tag(0) !== 'RIFF' || tag(8) !== 'WAVE' || view.getUint32(4, true) + 8 > bytes.length) {
        return bad();
    }
    let format = false, start = 0, length = 0;
    for (let at = 12; at + 8 <= bytes.length;) {
        const size = view.getUint32(at + 4, true), next = at + 8 + size;
        if (next > bytes.length) {
            return bad();
        }
        if (tag(at) === 'fmt ') {
            if (size < 16 || view.getUint16(at + 8, true) !== 1 || view.getUint16(at + 10, true) !== 1 || view.getUint32(at + 12, true) !== 16000 || view.getUint16(at + 22, true) !== 16) {
                return bad();
            }
            format = true;
        }
        if (tag(at) === 'data') {
            start = at + 8;
            length = size;
        }
        at = next + (size % 2);
    }
    if (!format || !start || !length || length % 2 || length > 16000 * 2 * 60) {
        return bad();
    }
    return bytes.slice(start, start + length);
}
exports.wavPcm = wavPcm;

},
"model/AiHistory":function(require,module,exports){
"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.boundedHistory = void 0;
function utf8Size(text) { let n = 0; for (let i = 0; i < text.length; i++) {
    const code = text.charCodeAt(i);
    if (code < 128) {
        n++;
    }
    else if (code < 2048) {
        n += 2;
    }
    else if (code >= 0xD800 && code <= 0xDBFF && i + 1 < text.length && text.charCodeAt(i + 1) >= 0xDC00 && text.charCodeAt(i + 1) <= 0xDFFF) {
        n += 4;
        i++;
    }
    else {
        n += 3;
    }
} return n; }
/** Preserve the visible library; bound only outbound context, prioritizing recent turns. */
function boundedHistory(messages, reserved) {
    let budget = 7 * 1024 * 1024 - utf8Size(reserved) - 4096;
    if (budget < 0) {
        throw new Error('本次内容较大，请减少附带记录或图片后重试');
    }
    const selected = [];
    for (let i = messages.length - 1; i >= 0 && selected.length < 80; i--) {
        const row = JSON.parse(JSON.stringify(messages[i]));
        if (row.content.length > 1000000) {
            row.content = row.content.slice(0, 999900).replace(/[\uD800-\uDBFF]$/, '') + '\n[较长的历史回复已截短]';
        }
        // Old pictures need not be resent every turn; the latest two turns retain them if they fit.
        if (i < messages.length - 2) {
            row.images = undefined;
        }
        let cost = utf8Size(JSON.stringify(row));
        if (cost > budget && row.images?.length) {
            row.images = undefined;
            cost = utf8Size(JSON.stringify(row));
        }
        if (cost > budget) {
            break;
        }
        budget -= cost;
        selected.unshift(row);
    }
    while (selected.length && selected[0].role !== 'user') {
        selected.shift();
    }
    return selected;
}
exports.boundedHistory = boundedHistory;

}},cache={};function load(name){if(cache[name])return cache[name].exports;if(!modules[name])throw Error('Unknown core module '+name);const m={exports:{}};cache[name]=m;modules[name](rel=>{const a=name.split('/');a.pop();for(const s of rel.split('/')){if(s==='..')a.pop();else if(s!=='.')a.push(s);}return load(a.join('/'));},m,m.exports);return m.exports;}window.WhaleCore=Object.fromEntries(["engine/Types","engine/TaskRules","engine/Scheduler","model/AppTime","model/AppTheme","model/MobileModel","model/SyncPlan","model/AssistantPlan","model/CalendarImport","model/SharingModel","model/ReminderPlan","model/ZonePolicy","model/AudioWav","model/AiHistory"].map(n=>[n.split('/').pop(),load(n)]));})();
