const fs = require('fs');
const path = require('path');

const keysToAdd = {
    "area_schedule_title": "Schedule Meetpoint",
    "area_select_date": "Select Date",
    "area_select_time": "Select Time",
    "area_reminder_label": "Reminder",
    "area_reminder_none": "None",
    "area_reminder_mins": "{} minutes before",
    "msg_meetpoint_at": "Meet at {} on {}"
};

const dir = 'assets/translations';
const files = fs.readdirSync(dir).filter(f => f.endsWith('.json'));

files.forEach(file => {
    const filePath = path.join(dir, file);
    console.log(`Processing ${file}...`);
    try {
        const content = JSON.parse(fs.readFileSync(filePath, 'utf8'));
        let modified = false;
        for (const [key, value] of Object.entries(keysToAdd)) {
            if (!(key in content)) {
                content[key] = value;
                modified = true;
            }
        }
        if (modified) {
            fs.writeFileSync(filePath, JSON.stringify(content, null, 2), 'utf8');
            console.log(`Updated ${file}`);
        } else {
            console.log(`No changes needed for ${file}`);
        }
    } catch (e) {
        console.error(`Failed to process ${file}: ${e.message}`);
    }
});
