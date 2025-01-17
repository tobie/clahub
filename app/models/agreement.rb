class Agreement < ActiveRecord::Base
  belongs_to :user
  has_many :signatures
  has_many :signing_users, through: :signatures, source: :user

  validates :repo_name, presence: true
  validates :user_name, presence: true
  validates :text, presence: true
  validate :one_agreement_per_user_repo

  attr_accessible :repo_name, :text

  before_validation :set_user_name_from_user_nickname

  def create_github_repo_hook
    hook_inputs = {
      'name' => 'web',
      'config' => {
        'url' => "#{HOST}/repo_hook"
      }
    }

    response = GithubRepos.new(self.user).create_hook(user_name, repo_name, hook_inputs)

    self.update_attribute(:github_repo_hook_id, response['id'])
  end

  def delete_github_repo_hook
    if github_repo_hook_id
      GithubRepos.new(self.user).delete_hook(user_name, repo_name, github_repo_hook_id)
      self.update_attribute(:github_repo_hook_id, nil)
    end
  end

  def owned_by?(candidate)
    candidate == self.user
  end

  def signed_by?(candidate)
    signing_users.include?(candidate)
  end

  def check_open_pulls
    # TODO: async this so that creating a signature doesn't take so long.
    CheckOpenPullsJob.new(owner: user, repo_name: repo_name).run
  end

  private

  def set_user_name_from_user_nickname
    self.user_name = user.try(:nickname)
  end

  def one_agreement_per_user_repo
    if Agreement.exists?(user_name: user_name, repo_name: repo_name)
      errors[:base] << "An agreement already exists for #{user_name}/#{repo_name}"
    end
  end
end
