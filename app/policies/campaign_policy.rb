class CampaignPolicy < ApplicationPolicy
  def index?
    @account_user.administrator?
  end

  def update?
    @account_user.administrator?
  end

  def fetchCampaignContacts?
    @account_user.administrator?
  end

  def show?
    @account_user.administrator?
  end

  def create?
    @account_user.administrator?
  end

  def destroy?
    @account_user.administrator?
  end
end
