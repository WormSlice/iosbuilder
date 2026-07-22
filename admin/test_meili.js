import { MeiliSearch } from 'meilisearch';

const client = new MeiliSearch({
  host: 'http://127.0.0.1:7700',
  apiKey: 'master_key',
});

async function test() {
  try {
    const health = await client.health();
    console.log('Meilisearch Health:', health);
    const stats = await client.getStats();
    console.log('Meilisearch Stats:', stats);
  } catch (e) {
    console.error('Meilisearch Error:', e);
  }
}

test();
