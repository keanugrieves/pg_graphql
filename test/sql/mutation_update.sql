begin;

    create table account(
        id serial primary key,
        email varchar(255) not null
    );

    create function _echo_email(account)
        returns text
        language sql
    as $$ select $1.email $$;

    create table blog(
        id serial primary key,
        owner_id integer not null references account(id) on delete cascade,
        name varchar(255) not null
    );
    comment on table blog is e'@graphql({"totalCount": {"enabled": true}})';

    insert into public.account(email)
    values
        ('aardvark@x.com'),
        ('bat@x.com'),
        ('cat@x.com'),
        ('dog@x.com'),
        ('elephant@x.com');

    insert into blog(owner_id, name)
    values
        (1, 'A: Blog 1'),
        (1, 'A: Blog 2'),
        (2, 'A: Blog 3'),
        (2, 'B: Blog 3');

    savepoint a;

    -- Check atMost clause stops deletes
    select graphql.resolve($$
    mutation {
      updateAccountCollection(
        set: {
          email: "new@email.com"
        }
        filter: {
          email: {eq: "bat@x.com"}
        }
        atMost: 0
      ) {
        records { id }
      }
    }
    $$);

    rollback to savepoint a;

    -- Check update works and allows nested response
    select graphql.resolve($$
        mutation {
          updateAccountCollection(
            set: {
              email: "new@email.com"
            }
            filter: {
              id: {eq: 2}
            }
            atMost: 1
          ) {
            affectedCount
            records {
              id
              echoEmail
              blogCollection {
                  totalCount
              }
            }
          }
        }
    $$);

    rollback to savepoint a;

    -- Check no matches returns empty array vs null + allows top xyz alias
    select jsonb_pretty(
        graphql.resolve($$
            mutation {
              xyz: updateAccountCollection(
                set: {
                  email: "new@email.com"
                }
                filter: {
                  email: {eq: "no@match.com"}
                }
                atMost: 1
              ) {
                records { id }
              }
            }
        $$)
    );

    rollback to savepoint a;

    -- Check no filter updates all records
    select jsonb_pretty(
        graphql.resolve($$
            mutation {
              updateAccountCollection(
                set: {
                  email: "new@email.com"
                }
                atMost: 8
              ) {
                records { id }
              }
            }
        $$)
    );

    rollback to savepoint a;

    -- set is variable
    select jsonb_pretty(
        graphql.resolve($$
            mutation SomeMut($setArg: AccountUpdateInput!) {
              updateAccountCollection(
                set: $setArg
                atMost: 8
              ) {
                records { id }
              }
            }
        $$,
        '{"setArg": {"email": "new@email.com"}}'
    ));

    rollback to savepoint a;

    -- set contains variable
    select jsonb_pretty(
        graphql.resolve($$
            mutation SomeMut($setArg: String!) {
              updateAccountCollection(
                set: {email: $setArg}
                atMost: 8
              ) {
                records { id }
              }
            }
        $$,
        '{"setArg": "new@email.com"}'
    ));

    rollback to savepoint a;



    -- forgot `set` arg
    select jsonb_pretty(
        graphql.resolve($$
            mutation {
              xyz: updateAccountCollection(
                filter: {
                  email: {eq: "not_relevant@x.com"}
                }
                atMost: 1
              ) {
                records { id }
              }
            }
        $$)
    );

    -- `atMost` can be omitted b/c it has a default
    select graphql.resolve($$
        mutation {
          updateAccountCollection(
            set: {
              email: "new@email.com"
            }
            filter: {
              id: {eq: 2}
            }
          ) {
            records { id }
          }
        }
    $$);

    -- pass integer as a variable to `set`
    -- https://twitter.com/aiji42_dev/status/1512305435017023489
    select graphql.resolve($$
        mutation SetVar($ownerId: Int) {
          updateBlogCollection(
            set: {
              ownerId: $ownerId
            }
            atMost: 10
          ) {
            records { ownerId }
          }
        }
    $$,
    '{"ownerId": 1}'
);


rollback;
