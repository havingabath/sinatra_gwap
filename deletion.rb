get '/chain/:id/delete' do  
  l1 = L1attempt.get params[:id]
  l2 = L2attempt.get params[:id]
  chain = Chain.get params[:id]
  l1.destroy if l1
  l2.destroy if l2
  chain.destroy if chain  
  redirect '/admin_data'  
end