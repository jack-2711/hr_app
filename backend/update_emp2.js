const bcrypt = require('bcryptjs');
const supabase = require('./db/supabase');

async function update() {
    const oldEmail = 'emp2@gmail.com';
    const newEmail = 'emp2@company.com';
    const password = 'password123';

    console.log('Generating hash...');
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    console.log('Updating user:', oldEmail, 'to', newEmail);
    const { data, error } = await supabase
        .from('profiles')
        .update({
            email: newEmail,
            password: hashedPassword
        })
        .eq('email', oldEmail)
        .select();

    if (error) {
        console.error('Error updating user:', error);
    } else if (data.length === 0) {
        console.log('User emp2@gmail.com not found. Checking if emp2@company.com already exists...');
        const { data: existing } = await supabase.from('profiles').select().eq('email', newEmail).single();
        if (existing) {
             await supabase.from('profiles').update({ password: hashedPassword }).eq('email', newEmail);
             console.log('Updated existing emp2@company.com password.');
        } else {
            console.log('Neither email found. Please check list_users.js output.');
        }
    } else {
        console.log('SUCCESS! emp2@company.com is now ready.');
        console.log('Login: emp2@company.com / password123');
    }
}

update();
