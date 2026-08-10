from django.http import HttpResponse
from django.views import View

from .models import TenantInvite


class InviteLandingView(View):
    """
    HTTP page opened from email. Tapping the button opens the RentEase app
    via deep link (rentease://...). Gmail blocks custom schemes in emails,
    so this HTTP page is the bridge.
    """

    def get(self, request, token):
        invite = TenantInvite.objects.filter(token=token).first()
        deep_link = f"rentease://login?invite_token={token}"

        if invite is None:
            status_msg = "This invite link is invalid."
            show_button = False
        elif invite.is_accepted:
            status_msg = "This invite has already been accepted. Open the app and log in."
            show_button = False
        else:
            status_msg = "You're invited to join RentEase. Tap below to open the app, then continue with Google to join as a tenant."
            show_button = True

        button_html = ""
        if show_button:
            button_html = f"""
              <a class="btn" href="{deep_link}">Open RentEase App</a>
              <p class="hint">If nothing happens, install RentEase first, then tap again.</p>
              <script>
                // Auto-try opening the app once
                setTimeout(function() {{
                  window.location.href = "{deep_link}";
                }}, 400);
              </script>
            """

        html = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>RentEase Invite</title>
  <style>
    body {{
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: #F5F7FA;
      margin: 0;
      padding: 24px;
      color: #1A3C6E;
    }}
    .card {{
      max-width: 420px;
      margin: 48px auto;
      background: white;
      border-radius: 20px;
      padding: 28px 24px;
      box-shadow: 0 8px 24px rgba(0,0,0,0.08);
      text-align: center;
    }}
    h1 {{ font-size: 22px; margin: 0 0 12px; }}
    p {{ color: #555; line-height: 1.5; font-size: 15px; }}
    .btn {{
      display: inline-block;
      margin-top: 20px;
      background: #1A3C6E;
      color: white !important;
      text-decoration: none;
      padding: 14px 22px;
      border-radius: 12px;
      font-weight: 600;
    }}
    .hint {{ font-size: 12px; color: #888; margin-top: 16px; }}
  </style>
</head>
<body>
  <div class="card">
    <h1>RentEase</h1>
    <p>{status_msg}</p>
    {button_html}
  </div>
</body>
</html>"""
        return HttpResponse(html)
