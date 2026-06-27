create or replace function calculate_order_total(p_order_id int)
returns double precision
language plpgsql
as
$$
declare
    res_sum int;
begin
    select
        case
            when count(product_id) > 0 then sum(quantity * price)
            when count(product_id) = 0 then 0
        end
    into res_sum
    from order_items
    where order_id = p_order_id;

    return res_sum;
end;
$$;

create or replace procedure create_order(p_customer_id int)
language plpgsql as
$$
    declare
        amount_to_insert int = 0;
        customer_id_count int;
    begin
        select count(*) from customers where customer_id = p_customer_id
        into customer_id_count;

        if customer_id_count > 0
        then
            insert into orders (customer_id, total_amount)
            values (p_customer_id, amount_to_insert);
        end if;
    end;
$$;

create or replace procedure add_product_to_order(
    p_order_id int,
    p_product_id int,
    p_quantity int
)
language plpgsql as
$$
    declare
        order_exists bool;
        product_price numeric(10, 2);
        product_quantity int;
    begin
        select exists(select 1 from orders where order_id = p_order_id)
        into order_exists;

        select price, stock_quantity
        from products
        where product_id = p_product_id
        into product_price, product_quantity;

        if order_exists and
           product_quantity is not null and
           product_quantity >= p_quantity
        then
            insert into order_items
                (order_id,
                 product_id,
                 quantity,
                 price)
            values
                (p_order_id,
                p_product_id,
                p_quantity,
                product_price);

            update products
            set stock_quantity = stock_quantity - p_quantity
            where product_id = p_product_id;
        end if;
    end;
$$;

create or replace function update_order_total()
returns trigger
language plpgsql as
$$
    begin
        update orders
        set total_amount = calculate_order_total(order_id)
        where order_id = new.order_id;
        return new;
    end;
$$;

create or replace trigger trg_update_order_total
after insert on order_items
for each row
execute function update_order_total();

create or replace function order_audit_log()
returns trigger
language plpgsql as
$$
    begin
        insert into order_log (order_id, customer_id, action, log_date)
        values (new.order_id,
                new.customer_id,
                'add order',
                now()::timestamp);
        return new;
    end;
$$;

create or replace trigger trg_order_audit_log
after insert on orders
for each row
execute function order_audit_log();
