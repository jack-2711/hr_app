const bcrypt = require('bcryptjs');
const supabase = require('./db/supabase');

async function update() {
    const email = 'admin1@company.com';
    const password = 'password123';

    console.log('Generating hash...');
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    console.log('Updating password for existing user:', email);
    const { data, error } = await supabase
        .from('profiles')
        .update({ password: hashedPassword })
        .eq('email', email)
        .select();

    if (error) {
        console.error('Error updating user:', error);
    } else {
        console.log('SUCCESS! admin1@company.com is now updated.');
        console.log('You can login with: admin1@company.com / password123');
    }
}

update();
