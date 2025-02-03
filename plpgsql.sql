do $$
	declare 
		tablename varchar;
		result_row record;
		command_create_table varchar;
		command_insert_table varchar;
	begin
		for result_row in (
			select distinct product_type, is_company 
			from bid
			order by product_type
		) loop
		case when result_row.is_company then
			tablename := concat('company_', result_row.product_type);
		else 
			tablename := concat('person_', result_row.product_type);
		end case;
		command_create_table := concat('create table if not exists ', tablename,
			'(id serial, client_name varchar, amount numeric(12,2));');
		execute command_create_table;
		command_insert_table := concat('insert into ', tablename, ' (client_name, amount) ',
			'select client_name, amount 
			from bid 
			where product_type = $1 and is_company = $2;'
		);	
		execute command_insert_table 
		using result_row.product_type, result_row.is_company;
		end loop;
	end;
$$;

do $$
	declare
		base_rate numeric := 0.1; 
	begin
		create table if not exists credit_percent ( 
			client_name varchar,
			amount numeric
		);
		execute 'insert into credit_percent (client_name, amount)
				(select client_name, ((amount * $1) / 365) 
				from person_credit
				union all
				select client_name, ((amount * ($1 + 0.05)) / 365)
				from company_credit)' 
		using base_rate;
		raise notice 'Общая сумма начисленных процентов по всем клиентам = %', 
			(select round(sum(amount), 2) from credit_percent);
	end;
$$;

do $$
	begin
		create view company_bid as (
			select * 
			from bid 
			where is_company = true
		);
		exception when duplicate_table then
			raise notice 'Представление company_bid (заявки команий) уже существует';
	end;
$$;