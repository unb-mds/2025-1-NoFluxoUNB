const { exec } = require('child_process');
exec('git checkout src/lib/components/plano-formatura/PlannerChatPanel.svelte', { cwd: __dirname }, (error, stdout, stderr) => {
    if (error) {
        console.error(`exec error: ${error}`);
        return;
    }
    console.log(`stdout: ${stdout}`);
    console.error(`stderr: ${stderr}`);
});
