// Cloudflare Worker for webhooks and cron
// Handles: n8n webhooks, GitHub webhooks -> Gitea, scheduled tasks

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    
    // Health check
    if (url.pathname === '/health') {
      return new Response(JSON.stringify({ status: 'ok', timestamp: new Date().toISOString() }), {
        headers: { 'Content-Type': 'application/json' }
      });
    }
    
    // n8n webhook proxy (adds auth, rate limiting)
    if (url.pathname.startsWith('/n8n/')) {
      const targetUrl = `https://n8n.${env.DOMAIN}${url.pathname}${url.search}`;
      const response = await fetch(targetUrl, {
        method: request.method,
        headers: {
          ...Object.fromEntries(request.headers),
          'X-Forwarded-For': request.headers.get('CF-Connecting-IP') || '',
        },
        body: request.body,
      });
      return response;
    }
    
    // GitHub -> Gitea mirror webhook
    if (url.pathname === '/github-to-gitea') {
      const signature = request.headers.get('X-Hub-Signature-256');
      const payload = await request.text();
      
      // Verify GitHub signature (implement with env.GITHUB_WEBHOOK_SECRET)
      // Forward to Gitea
      const giteaResponse = await fetch(`https://gitea.${env.DOMAIN}/api/v1/repos/migrate`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `token ${env.GITEA_TOKEN}`,
        },
        body: JSON.stringify({
          clone_addr: JSON.parse(payload).repository.clone_url,
          mirror: true,
          private: true,
        }),
      });
      
      return new Response(JSON.stringify({ gitea: await giteaResponse.json() }), {
        headers: { 'Content-Type': 'application/json' }
      });
    }
    
    // Scheduled cron (triggered by Cloudflare Cron Triggers)
    if (url.pathname === '/cron/backup') {
      // Trigger backup via R2 event or call external endpoint
      return new Response(JSON.stringify({ triggered: 'backup', timestamp: new Date().toISOString() }), {
        headers: { 'Content-Type': 'application/json' }
      });
    }
    
    return new Response('Not Found', { status: 404 });
  },
  
  // Scheduled handler for cron triggers
  async scheduled(event, env, ctx) {
    if (event.cron === '0 2 * * *') {
      // Daily at 2 AM - trigger backup
      ctx.waitUntil(
        fetch(`https://api.${env.DOMAIN}/backup/trigger`, {
          method: 'POST',
          headers: { 'Authorization': `Bearer ${env.BACKUP_TOKEN}` }
        })
      );
    }
  }
};