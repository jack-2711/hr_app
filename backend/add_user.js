const bcrypt = require('bcryptjs');
const supabase = require('./db/supabase');

async function addUser() {
    const email = 'admin@company.com';
    const password = 'password123';

    console.log('Generating hash...');
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    console.log('Cleaning up existing user if any:', email);
    await supabase.from('profiles').delete().eq('email', email);

    console.log('Inserting fresh admin user (omitting ID to let DB generate)...');
    const { data, error } = await supabase
        .from('profiles')
        .insert([
            {
                email: email,
                full_name: 'System Admin',
                password: hashedPassword,
                role: 'admin',
                status: 'active'
            }
        ])
        .select();

    if (error) {
        console.error('Error adding user:', error);
        console.log('Attempting fix: providing a manual UUID...');

        const manualId = '660e8400-e29b-41d4-a716-446655440066';
        const { error: error2 } = await supabase
            .from('profiles')
            .insert([{
                id: manualId,
                email: email,
                full_name: 'System Admin',
                password: hashedPassword,
                role: 'admin',
                status: 'active'
            }]);

        if (error2) {
            console.error('Manual ID insertion also failed:', error2);
        } else {
            console.log('SUCCESS with manual ID! User:', email);
        }
    } else {
        console.log('SUCCESS! Admin user created:', email, '/ password123');
    }
}

addUser();
