class Identity < ApplicationRecord
  has_one :user, dependent: :destroy

  validates :email, presence: true, uniqueness: { case_sensitive: false }

  normalizes :email, with: ->(e) { e.strip.downcase }

  CODE_TTL = 10.minutes

  # Generate a 6-digit code, store its digest, return the plaintext to email.
  def issue_login_code!
    code = format("%06d", SecureRandom.random_number(1_000_000))
    update!(
      login_code_digest: BCrypt::Password.create(code),
      login_code_expires_at: CODE_TTL.from_now
    )
    code
  end

  def login_code_valid?(submitted)
    return false if login_code_digest.blank? || login_code_expires_at.blank?
    return false if login_code_expires_at.past?
    BCrypt::Password.new(login_code_digest) == submitted.to_s
  end

  def clear_login_code!
    update!(login_code_digest: nil, login_code_expires_at: nil)
  end
end
