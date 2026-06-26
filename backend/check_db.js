const supabase = require('./db/supabase');

async function check() {
    const { data, error } = await supabase.from('profiles').select().limit(1);
    if (error) {
        console.error('Error fetching profiles:', error);
    } else {
        console.log('Columns found in profiles:', data.length > 0 ? Object.keys(data[0]) : 'No data to check columns');
    }
}
check();
