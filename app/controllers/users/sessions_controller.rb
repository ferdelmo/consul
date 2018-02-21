require 'rubygems'
require 'net-ldap'

class Users::SessionsController < Devise::SessionsController
  def create
    # CHEQUEO EL CENSO
    User.find_by username: params[:user][:login]

    grupoAsociado=Geozone.find_by id: params[:grupo]
    censo_code=grupoAsociado[:census_code]
    resul=Censo.find_by NIP: params[:user][:login], grupo: censo_code
    grupo=(params[:user][:login]=='admin' || resul);
    #censo=IO.readlines("/home/pruebasae/censo.txt")
    #censo.each do |linea|
    #  nip=linea.split(" ").first
    #  grupos=linea.split(" ").last
    #  print "NIP: "
    #  print nip
    #  print " GRUPOS: "
    #  print grupos
    #  if(nip=params[:user][:login])
    #    array=grupos.split(",")
    #    array.each do |gr|
    #      if gr==params[:grupo]
    #        grupo=true
    #      end
    #    end
    #  end
    #end


    # CHEQUECO CONTRA LDAP

    # Si LDAP = TRUE
      # comproabr si esxiste el usuario
      # sino existe crearlo con contraseña=A
    # SI LDAP = FALSE
      # devolver error
    useraux=""
    ldap = Net::LDAP.new :host => 'ldapmail.unizar.es',
     :port => 389
     #   $filter = "(&(".$cfgldap['LDAPNIP']."=".$nip.")(objectClass=person))";
    filter = Net::LDAP::Filter.eq("uid", params[:user][:login])
    treebase = "ou=Admon,dc=unizar,dc=es"
    if ldap.bind
      print "CONNECTADO CON LDAP"
    else 
      print "FALLO EN LA CONEXION"
    end
    ldap.search(:base => treebase, :filter => filter) do |entry|
      puts "DN: #{entry.dn}"
      useraux = entry.dn
      entry.each do |attribute, values|
        puts "   #{attribute}:"
        values.each do |value|
          puts "      --->#{value}"
        end
      end
    end

    p ldap.get_operation_result

    ldap = Net::LDAP.new :host => 'ldapmail.unizar.es',
     :port => 389, :base => "ou=Admon,dc=unizar,dc=es",
     :auth => {
           :method => :simple,
           :username => useraux,
           :password => params[:user][:password]
    }
    print useraux
    print " \n INTENTA CONECTAR CON LO ENCONTRADO\n"
    if ldap.bind && params[:user][:password]!="" && grupo
      print "SE CONECTA CON LDAP"
      if User.find_by username: params[:user][:login]
        @user=User.find_by username: params[:user][:login]
        @user[:geozone_id]=params[:grupo]
        print "ESTA EN EL GRUPO"
        print params[:grupo]
        print "\n"
        @user.save
        print @user[:username]
        print "EL USUARIO YA EXISTE; SIGN IN\n"
        set_flash_message(:notice, :signed_in)
        sign_in(@user)
        yield resource if block_given?
        respond_with resource, location: after_sign_in_path_for(resource)
      else 
        print "el usuario "
        print params[:user][:login]
        print " NO existe\n"
        print "ESTA EN EL GRUPO"
        print params[:grupo]
        print "\n"
        mail = params[:user][:login] + "@unizar.com"
        @user = User.create!(username: params[:user][:login], 
          email: mail, password: "vacioVACIO", 
          password_confirmation: "vacioVACIO", 
          confirmed_at: Time.current, terms_of_service: "1",
          verified_at: Time.current, geozone_id: params[:grupo])
        
        @user.save
        print "SE GUARDA EL USUARIO"

        set_flash_message(:notice, :signed_in)
        sign_in(@user)
        yield resource if block_given?
        respond_with resource, location: after_sign_in_path_for(resource)
      end
    else
    	if(params[:user][:login]!='admin')
	     	self.resource = warden.authenticate!(auth_options)
	     	env['warden'].logout
		    set_flash_message(:notice, :invalido) if is_flashing_format?
		    redireccion = root_url + "users/sign_in"
		    respond_with(resource) do |format|
		      format.json { render json: {redirect_url: redireccion }, status: 401 }
		      format.html { redirect_to(root_url + "users/sign_in") }
		    end
  		else
  			self.resource = warden.authenticate!(auth_options)
  			sign_in(@user)
        yield resource if block_given?
        respond_with resource, location: after_sign_in_path_for(resource)
  		end
    end
    
  end
  private

    def after_sign_in_path_for(resource)
      if !verifying_via_email? && resource.show_welcome_screen?
        welcome_path
      else
        super
      end
    end

    def after_sign_out_path_for(resource)
      request.referer.present? ? request.referer : super
    end

    def verifying_via_email?
      return false if resource.blank?
      stored_path = session[stored_location_key_for(resource)] || ""
      stored_path[0..5] == "/email"
    end

end
