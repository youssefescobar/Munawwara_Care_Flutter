const fs = require('fs');
const path = require('path');

const keysToAdd = {
    "area_name_desc_header": "Name & Description",
    "area_date_label": "Date",
    "area_time_label": "Time"
};

const dir = 'assets/translations';
const files = fs.readdirSync(dir).filter(f => f.endsWith('.json'));

files.forEach(file => {
    const filePath = path.join(dir, file);
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
        }
    } catch (e) {
        console.error(`Failed to process ${file}: ${e.message}`);
    }
});
