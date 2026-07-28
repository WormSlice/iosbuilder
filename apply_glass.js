const fs = require('fs');
const path = require('path');

const srcDir = path.join(__dirname, 'admin', 'src');

function walkSync(dir, callback) {
    const files = fs.readdirSync(dir);
    files.forEach((file) => {
        var filepath = path.join(dir, file);
        const stats = fs.statSync(filepath);
        if (stats.isDirectory()) {
            walkSync(filepath, callback);
        } else if (stats.isFile() && filepath.endsWith('.tsx')) {
            callback(filepath);
        }
    });
}

const replacements = [
    { regex: /\bbg-white\b/g, replacement: 'glass-panel' },
    { regex: /\bbg-black\b/g, replacement: 'glass-panel-dark' },
    { regex: /\bbg-zinc-50\b/g, replacement: 'glass-button' },
    { regex: /\bbg-zinc-100\b/g, replacement: 'glass-button' },
    { regex: /\bbg-zinc-800\b/g, replacement: 'glass-panel-dark' },
    { regex: /\bbg-zinc-900\b/g, replacement: 'glass-panel-dark' },
    // Remove background opacity utilities if they are attached to bg-white
    { regex: /glass-panel\/\d+/g, replacement: 'glass-panel' },
    { regex: /glass-panel-dark\/\d+/g, replacement: 'glass-panel-dark' },
    { regex: /glass-button\/\d+/g, replacement: 'glass-button' },
];

walkSync(srcDir, (filepath) => {
    let content = fs.readFileSync(filepath, 'utf8');
    let original = content;

    replacements.forEach(({ regex, replacement }) => {
        content = content.replace(regex, replacement);
    });

    if (content !== original) {
        fs.writeFileSync(filepath, content, 'utf8');
        console.log(`Updated ${filepath}`);
    }
});
