# People sign in rarely (magic link), so a session lasts a year instead of ending with the browser.
Rails.application.config.session_store :cookie_store, key: "_home_hq_session", expire_after: 1.year
