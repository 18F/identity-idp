module SessionHelper
  def clear_session
    user_session['idv/doc_auth'] = {}
    user_session['idv/in_person'] = {}
    user_session['idv/inherited_proofing'] = {}
    idv_session.clear
    Pii::Cacher.new(current_user, user_session).delete
  end
end
