const supabase = require('./db/supabase');

async function list() {
    const { data, error } = await supabase.from('profiles').select('id, email, full_name, role');
    if (error) {
        console.error('Error fetching users:', error);
    } else {
        console.log('Current users in profiles:', data);
    }
}
list();
